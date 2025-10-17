# Deprecated

FIXME(d1y): 这部分已经过时, 需要更新

# Schema

`asset.json` 是源合集列表格式

```json
{
  "$schema": "https://raw.githubusercontent.com/waifu-project/movie/dev/schema/assets.json",
  "data": [
    {
      "title": "源名称",
      "url": "采集地址, 一般是地址合集",
      "msg": "源的说明, 一般是导入的时候用来提示的",
      "nsfw": "是否是 18+ 的源"
    }
  ]
}
```

`v1.json` 是源列表格式

```jsonc
{
  "$schema": "https://raw.githubusercontent.com/waifu-project/movie/dev/schema/v1.json",
  "data": [
    {
      "logo": "图标",
      "name": "名称",
      "desc": "说明",
      "api": {
        "root": "根域名",
        "path": "路径"
      },
      "nsfw": true,
      "jiexiUrl": "解析地址",
      "id": "id" // 填了没用, 会自动生成id
    }
  ]
}
```