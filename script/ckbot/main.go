package main

import (
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"net/url"
	"os"
	"regexp"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/PuerkitoBio/goquery"
	"github.com/charmbracelet/log"
	"github.com/imroc/req/v3"
	"github.com/longbridgeapp/opencc"
	"github.com/mozillazg/go-pinyin"
	"github.com/sourcegraph/conc/pool"
)

//go:embed template.html
var htmlTemplate string

var t2s *opencc.OpenCC

var ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36"

var pinyinContext = pinyin.NewArgs()

func isHTML(input string) bool {
	input = strings.ToLower(input)
	htmlMarkers := []string{"html", "<!d", "<body"}

	for _, htmlMarker := range htmlMarkers {
		if strings.Contains(input, htmlMarker) {
			return true
		}
	}

	return false
}

func isJSON(str string) bool {
	if strings.HasPrefix(str, "{") && strings.HasSuffix(str, "}") {
		return true
	}
	if strings.HasPrefix(str, "[") && strings.HasSuffix(str, "]") {
		return true
	}
	return false
}

func isXML(body string) bool {
	docStart := strings.TrimSpace(body)[:5]
	return docStart == "<?xml"
}

type ResponseType int

const (
	XMLT ResponseType = iota
	JSONT
	UnknownT
)

type Result struct {
	Idx    int          `json:"idx"`    // 索引(map会丢失)
	Parse  ParseResult  `json:"parse"`  // 上下文
	Logo   string       `json:"logo"`   // 图标
	OK     bool         `json:"ok"`     // 是否可用
	Time   string       `json:"time"`   // 耗时
	Reason string       `json:"reason"` // 原因
	Nsfw   bool         `json:"nsfw"`   // 是否是18+源
	Type   ResponseType `json:"type,omitempty"`
}

type GithubUser struct {
	Avatar   string `json:"avatar_url"`
	Login    string `json:"login"`
	HomePage string `json:"html_url"`
}

// 参考数据结构: https://api.github.com/repos/waifu-project/movie/issues/45/comments
type GithubIssueComment struct {
	ID        uint64      `json:"id"`
	Body      string      `json:"body"`
	User      *GithubUser `json:"user"`
	CreatedAt string      `json:"created_at"`
	UpdatedAt string      `json:"updated_at"`
	Text      []ParseResult
}

type Set[T comparable] struct {
	items map[T]struct{}
	mu    sync.Mutex
}

func NewSet[T comparable]() *Set[T] {
	return &Set[T]{
		items: make(map[T]struct{}),
	}
}

func (s *Set[T]) Add(value T) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.items[value] = struct{}{}
}

func (s *Set[T]) Has(value T) bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	_, exists := s.items[value]
	return exists
}

var domains = NewSet[string]()

func getDomainWithURL(urlStr string) (string, error) {
	u, err := url.Parse(strings.ToLower(urlStr))
	if err != nil {
		return "", fmt.Errorf("解析 URL 失败: %w", err)
	}
	if u.Host == "" {
		u, err = url.Parse("http://" + urlStr)
		if err != nil {
			return "", fmt.Errorf("添加 scheme 后解析 URL 失败: %w", err)
		}
	}
	host := u.Host
	if strings.Contains(host, ":") {
		host = strings.Split(host, ":")[0]
	}
	if strings.HasPrefix(host, "[") && strings.HasSuffix(host, "]") {
		host = strings.Trim(host, "[]")
	}
	return host, nil
}

func GetDomainAndProtocolWithURL(rawURL string) (string, error) {
	parsedURL, err := url.Parse(rawURL)
	if err != nil {
		return "", fmt.Errorf("解析URL失败: %w", err)
	}
	if parsedURL.Scheme == "" || parsedURL.Host == "" {
		return "", fmt.Errorf("URL格式不正确，缺少协议或主机")
	}
	return parsedURL.Scheme + "://" + parsedURL.Host, nil
}

func isOKAndResponseType(body string) (ResponseType, error) {
	var cx = strings.TrimSpace(body)
	if len(cx) == 0 {
		return UnknownT, errors.New("body 为空, 该接口无响应")
	}
	if cx == "err{0}" { // 错误的魔法值
		return UnknownT, errors.New("body 为错误值(err{0})")
	}
	if isHTML(cx) {
		return UnknownT, errors.New("body 为 html 格式, 不支持或者该域名已经过期")
	}
	if isXML(body) {
		return XMLT, nil
	}
	if isJSON(body) {
		return JSONT, nil
	}
	return UnknownT, errors.New("body 不是 xml 或者 json 格式")
}

func getGithubIssueComments(owner, repo, issueID, token string) map[uint64]GithubIssueComment {
	var url = fmt.Sprintf("https://api.github.com/repos/%s/%s/issues/%s/comments", owner, repo, issueID)
	var comments []GithubIssueComment
	req.SetQueryParam("per_page", "100").SetBearerAuthToken(token).SetSuccessResult(&comments).MustGet(url)
	var cx = make(map[uint64]GithubIssueComment)
	for _, comment := range comments {
		var texts = getItemWithText(comment.Body, cx)
		if len(texts) == 0 {
			// 如果全是重复的为空了, 那还要个毛线啊
			continue
		}
		comment.Text = texts
		cx[comment.ID] = comment
	}
	return cx
}

type ParseResult struct {
	ID   string `json:"id"`
	Text string `json:"name"`
	URL  string `json:"url"`
	Nsfw bool   `json:"nsfw"`
}

// 判断数组中是否包含单个
//
// 自动去除 / 尾部, 我怕它重复了
func resultIncludes(list []ParseResult, val ParseResult) bool {
	var url2 = strings.TrimSuffix(val.URL, "/")
	for _, item := range list {
		var url1 = strings.TrimSuffix(item.URL, "/")
		if url1 == url2 {
			return true
		}
	}
	return false
}

func parseName(raw string) string {
	var result = strings.TrimSpace(raw)
	text, err := t2s.Convert(result)
	if err != nil {
		return result
	}
	return text
}

func convertWithPreserve(s string) string {
	var result []string
	isAlnum := regexp.MustCompile(`^[a-zA-Z0-9]$`).MatchString

	for _, r := range s {
		char := string(r)
		if isAlnum(char) {
			result = append(result, char)
		} else {
			py := pinyin.Pinyin(char, pinyinContext)
			if len(py) > 0 && len(py[0]) > 0 {
				result = append(result, py[0][0])
			} else {
				result = append(result, char)
			}
		}
	}

	return strings.Join(result, "")
}

func getItemWithText(text string, cx map[uint64]GithubIssueComment) []ParseResult {
	var context []ParseResult
	for _, comment := range cx {
		context = append(context, comment.Text...)
	}
	var result []ParseResult
	var lines = strings.Split(strings.TrimSpace(text), "\n")
	var skip = true
	for _, _line := range lines {
		var line = strings.TrimSpace(_line)
		if strings.HasPrefix(line, "-----") {
			skip = false
			continue
		}
		if skip {
			continue
		}
		var syb = " "
		if strings.Contains(line, ",") {
			syb = ","
		}
		var ss = strings.Split(line, syb)
		if len(ss) <= 1 {
			continue
		}
		var text = parseName(ss[0])
		var url = strings.TrimSpace(ss[1])
		var id = convertWithPreserve(text) // FIXME(d1y): id 可能会重复
		var now = ParseResult{
			ID:   id,
			Text: text,
			URL:  url,
			Nsfw: false,
		}
		if len(ss) >= 3 {
			var flag = strings.TrimSpace(ss[2])
			var flags = []string{"true", "nsfw", "色情"}
			if slices.Contains(flags, flag) {
				now.Nsfw = true
			}
		}
		if resultIncludes(context, now) { //重复了就不添加
			continue
		}
		result = append(result, now)
	}
	return result
}

func findLogo(domain string) string {
	resp, err := req.Get(domain)
	if err != nil {
		return ""
	}
	html, err := resp.ToString()
	if err != nil {
		return ""
	}
	if !isHTML(html) {
		return ""
	}
	result := ""
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		return ""
	}
	// 1. 查找所有图片, 如果发现 src 属性中后缀是 logo.{png,jpg,gif} 就返回
	doc.Find("img").Each(func(i int, s *goquery.Selection) {
		if len(result) > 0 {
			return
		}
		src, ok := s.Attr("src")
		if !ok {
			return
		}
		var ms = []string{"logo.png", "logo.jpg", "logo.gif", "logo.jpeg"}
		for _, logo := range ms {
			if strings.HasSuffix(src, logo) {
				result = src
				return
			}
		}
	})
	if result != "" {
		if !strings.HasPrefix(result, "http") {
			result = fmt.Sprintf("%s%s", domain, result)
		}
		return result
	}
	// 2. 检测默认图标是否存在
	var logo1 = "/statics/img/logo_max_f.png"
	var logo2 = "/template/stui_tpl/statics/img/logo_max_f.png"
	var logo3 = "/static/jsui/img/logo_max_f.png"
	var logo4 = "/template/LB_zyz/statics/img/logo_max_f.png"
	var logo5 = "/template/ziyuan/img/logo_max_f.png"
	var defaultLogos = []string{logo1, logo2, logo3, logo4, logo5}
	for _, logo := range defaultLogos {
		var realLogo = fmt.Sprintf("%s%s", domain, logo)
		resp, err = req.Get(realLogo)
		if err == nil {
			if resp.StatusCode == 200 {
				return realLogo
			}
		}
	}
	return ""
}

func runTaskCheck(list []ParseResult, ccTaskCount int) []Result {
	var pool = pool.New().WithMaxGoroutines(ccTaskCount)
	var cx sync.Map // map[int][Result]
	for idx, item := range list {
		pool.Go(func() {
			var start = time.Now()
			var result Result
			defer func() {
				if r := recover(); r != nil {
					log.Error("Recovered", "err", r)
				}
			}()
			result.Idx = idx
			result.Parse = item
			domain, err := getDomainWithURL(item.URL)
			if err == nil {
				if domains.Has(domain) {
					log.Warn("跳过重复域名", "域名", domain, "链接", item.URL)
					result.Reason = fmt.Sprintf("跳过重复域名: %s", domain)
					result.Time = "0.00"
					cx.Store(idx, result)
					return
				} else {
					domains.Add(domain)
				}
			}
			resp, err := req.Get(item.URL)
			log.Info("检查资源", "名称", item.Text, "链接", item.URL)
			if err != nil {
				log.Error("请求资源失败", "名称", item.Text, "链接", item.URL, "reason", err)
				result.Reason = err.Error()
			} else {
				var body, err = resp.ToString()
				if err != nil {
					log.Error("解析资源body失败", "名称", item.Text, "链接", item.URL, "reason", err)
					result.Reason = err.Error()
				} else {
					rt, err := isOKAndResponseType(body)
					if err != nil {
						result.Reason = err.Error()
						log.Error("验证资源body失败", "名称", item.Text, "链接", item.URL, "reason", err)
					} else {
						result.Nsfw = item.Nsfw
						result.Type = rt
						result.OK = true
						realDomain, _ := GetDomainAndProtocolWithURL(item.URL)
						result.Logo = findLogo(realDomain)
						log.Info("检查资源成功", "名称", item.Text, "链接", item.URL, "NSFW", result.Nsfw)
					}
				}
			}
			var s = time.Since(start).Seconds()
			result.Time = fmt.Sprintf("%.2f", s)
			cx.Store(idx, result)
		})
	}
	pool.Wait()
	var result []Result
	cx.Range(func(key, value any) bool {
		result = append(result, value.(Result))
		return true
	})
	return result
}

type v1 struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Logo   string `json:"logo,omitempty"`
	Nsfw   bool   `json:"nsfw"`
	API    v1API  `json:"api"`
	Status bool   `json:"status"`
}

type v1API struct {
	Root string `json:"root"`
	Path string `json:"path"`
}

type htmlDataStruct struct {
	Data    []Result           `json:"data"`
	Comment GithubIssueComment `json:"comment"`
}
type htmlStruct struct {
	NowTime string                    `json:"now"`
	Correct int                       `json:"correct"`
	Err     int                       `json:"err"`
	Data    map[uint64]htmlDataStruct `json:"data"`
}

var cstSh, _ = time.LoadLocation("Asia/Shanghai")

func dumpToHTML(result map[uint64][]Result, cx map[uint64]GithubIssueComment, correct, err int) {
	var data = make(map[uint64]htmlDataStruct)
	for key, results := range result {
		data[key] = htmlDataStruct{
			Data:    results,
			Comment: cx[key],
		}
	}
	var output = htmlStruct{
		NowTime: time.Now().In(cstSh).Format("2006年01月02日 15时04分05秒"),
		Data:    data,
		Correct: correct,
		Err:     err,
	}
	buf, e := json.Marshal(output)
	if e != nil {
		panic(err)
	}
	var code = string(buf)
	var html = strings.ReplaceAll(htmlTemplate, "$$$$", code)
	var outHTML = os.Getenv("OUT_HTML")
	if outHTML != "" {
		os.WriteFile(outHTML, []byte(html), 0644)
	}
}

func dumpToJSON(_result map[uint64][]Result) (int, int) {
	var correct = 0
	var err = 0
	var pipe []Result
	var yoyoJSON []v1

	{
		for _, val := range _result {
			pipe = append(pipe, val...)
		}
		for _, val := range pipe {
			if val.OK {
				correct++
				var cx, err = url.Parse(val.Parse.URL)
				if err != nil {
					panic(err)
				}
				var root = fmt.Sprintf("%s://%s", cx.Scheme, cx.Host)
				var data = v1{ID: val.Parse.ID, Name: val.Parse.Text, Logo: val.Logo, Nsfw: val.Nsfw, API: v1API{Root: root, Path: cx.Path}, Status: true}
				yoyoJSON = append(yoyoJSON, data)
			} else {
				err++
			}
		}
	}

	var humanSize = fmt.Sprintf("%d/%d", correct, len(pipe))
	log.Info("检查完成", "当前可用", humanSize)

	var file = os.Getenv("OUTPUT")
	if file != "" {
		cx, err := json.MarshalIndent(yoyoJSON, "", "\t")
		if err != nil {
			panic(err)
		}
		os.WriteFile(file, cx, 0644)
	}

	return correct, err
}

func init() {
	req.SetUserAgent(ua)
	req.SetTimeout(time.Second * 9)
	req.EnableInsecureSkipVerify()
}

func main() {
	t2s, _ = opencc.New("t2s")
	log.Info("开始获取评论列表")
	var token = os.Getenv("GITHUB_TOKEN")
	if token == "" {
		panic("GITHUB_TOKEN 不能为空")
	}
	var bodys = getGithubIssueComments("waifu-project", "movie", "45", token)
	if len(bodys) == 0 {
		panic("从 github 评论中未获取到资源")
	}
	log.Infof("获取评论列表完成(解析到%d条评论)\n", len(bodys))
	var result = make(map[uint64][]Result)
	for _, item := range bodys {
		log.Info("开始检查资源组", "id", item.ID, "数量", len(item.Text))
		var data = runTaskCheck(item.Text, 12)
		result[item.ID] = data
	}
	var correct, err = dumpToJSON(result)
	dumpToHTML(result, bodys, correct, err)
	log.Info("完成")
}
