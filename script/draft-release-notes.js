const execSync = require('child_process').execSync

const noteReg = /Release Notes:([\s\S]+)/

// git show format spec: https://git-scm.com/docs/git-show#_pretty_formats
/** @param {string} hash */
function getCommitBody(hash) {
  const body = execSync(`git show ${hash} --stat=0 --no-patch --format="%b"`).toString('utf-8').trim()
  return body
}

/**
 * @param {string} body
 * @returns {string[] | null}
 */
function parseCommitBody(body) {
  if (!body) return null
  const cx = body.match(noteReg)
  if (!cx) return null
  const [ , notes ] = cx
  if (!notes) return null
  /** @type {string[]} */
  const result = notes.trim().split("\n").map(item=> {
    const _ = item.trim()
    if (!_.startsWith("-")) return null
    return _.replace(/^- /, "")
  }).filter(Boolean)
  if (!result.length) return null
  return result
}

/**
 * @param {string} a 
 * @param {string} b 
 * @returns 
 */
function getTwoTagCommitHashs(a, b) {
  return execSync(`git log --oneline --format="%h" ${a}...${b}`).toString('utf-8').trim().split("\n")
}

// function getLatestTags(size = 2) {
//   return execSync(`git tag -l --sort=-v:refname | head -${size}`).toString('utf-8').trim().split("\n")
// }

/**
 * @param {string} tag 
 */
function getTagNote(tag) {
  const _ = execSync(`git show ${tag} --stat=0 --no-patch --format="%N"`).toString('utf-8').trim()
  const note = _.split("\n").filter(item=> { return !!item.trim() })
  // 第一行第二行不需要
  note.shift()
  note.shift()
  return note.join("\n") + "\n"
}

const kRepo = "waifu-project/movie"

const fastGithubDomains = [
  // https://gh-proxy.com
  { text: "全球加速", prefix: "https://gh-proxy.com" },
  { text: "香港加速", prefix: "https://hk.gh-proxy.com" },
  // https://ghproxy.link
  { text: "加速3", prefix: "https://ghfast.top" },
  { text: "原始", prefix: null },
]

function buildFastLink(fastPrefix, tag, file) {
  const raw = `https://github.com/${kRepo}/releases/download/${tag}/${file}`
  if (!fastPrefix) return raw
  return `${fastPrefix}/${raw}`
}

function buildRealFastLink(tag, file) {
  return fastGithubDomains.map((item)=> {
    const link = buildFastLink(item.prefix, tag, file)
    return `[${item.text}](${link})`
  }).join(" \\| ")
}

function getChinaDate() {
  const chinaDate = new Intl.DateTimeFormat('zh-CN', {
    timeZone: 'Asia/Shanghai',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit'
  }).format(new Date());
  return chinaDate.replace(/\//g, '-')
}

function buildReleaseHeader(tag) {
  const _ = (file)=> buildRealFastLink(tag, file)
  const date = getChinaDate()
return `
## 🐱 猫趣(${date})

| 系统     | 文件后缀 | 架构          | 下载链接 |
|---------|------|-------------|------|
| macOS   | .zip | 通用(universal)   |  ${_('catmovie-mac.zip')}  |
| iOS     | .ipa | -           |  ${_('catmovie.ipa')}    |   |   |
| Android | .apk | 常用(arm64-v8a)   |  ${_('catmovie.apk')}    |   |
| Android | .apk | 旧手机(armeabi-v7a) |  ${_('catmovie-legacy.apk')}   |
| Android | .apk | 通用(universal)   |  ${_('catmovie-universal.apk')}    |
| Windows | .zip | -            |  ${_('catmovie-windows.zip')}    |   |
| Linux   | .zip | -            | ${_('catmovie-linux-x86_64.tar.gz')}     |

## 赞助

**万水千山总是情, 微信转账300行不行 👀**
感谢您的支持, 这将让小猫可以继续走下去 🤗

<img src="https://s2.loli.net/2025/09/24/ByRvOsQhWzKLXNo.jpg" width="300" />

`
}

function buildRealNotes(tag, changelog) {
  const header = buildReleaseHeader(tag)
  return `
${header}  
## 📢 更新日志

${changelog}
`
}

// Github API 返回排序不太对, 这里需要手动排序一下
function sortTagsBySemVer(tags) {
  return [...tags].sort((a, b) => {
    const getVersion = (tagName) => tagName.replace(/^release-v/, '');
    const v1 = getVersion(a.name);
    const v2 = getVersion(b.name);
    const parts1 = v1.split(/[.-]/).map(p => isNaN(Number(p)) ? p : Number(p));
    const parts2 = v2.split(/[.-]/).map(p => isNaN(Number(p)) ? p : Number(p));
    for (let i = 0; i < Math.max(parts1.length, parts2.length); i++) {
      const p1 = i < parts1.length ? parts1[i] : -1;
      const p2 = i < parts2.length ? parts2[i] : -1;
      if (typeof p1 === 'number' && typeof p2 === 'number') {
        if (p1 !== p2) return p2 - p1;
      }
      else if (typeof p1 === 'string' && typeof p2 === 'string') {
        if (p1 !== p2) return p2.localeCompare(p1);
      }
      else {
        return typeof p1 === 'number' ? -1 : 1;
      }
    }
    return 0;
  });
}

;(async()=> {
  const token = process.env.GITHUB_TOKEN
  const resp = await fetch(`https://api.github.com/repos/${kRepo}/tags`, {
    headers: {
      "Authorization": `Bearer ${token}`
    }
  })
  /** @type {GithubTagResponse} */
  const _tags = await resp.json()
  const tags = sortTagsBySemVer(_tags)
  const now = tags[0].name//latest
  const old = tags[1].name//我赌你枪里没有子弹
  const hashs = getTwoTagCommitHashs(now, old)
  let notes = []
  for (const hash of hashs) {
    const body = getCommitBody(hash)
    const _ = parseCommitBody(body)
    if (_) {
      notes = [...notes, ..._]
    }
  }
  let releaseNote = getTagNote(now)
  releaseNote += notes.map(item=> `- ${item}`).join("\n")
  const note = buildRealNotes(now, releaseNote)
  console.log(note)
})()