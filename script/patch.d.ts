interface Tag {
  name: string
}

type GithubTagResponse = Array<Tag>

interface SourceItem {
  name: string
  nsfw: boolean
  api: {
    root: string
    path: string
  }
}