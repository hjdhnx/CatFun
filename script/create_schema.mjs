import fs from 'fs'

;(()=> {
  const spec = fs.readFileSync("packages/xi/lib/models/spec.dart").toString("utf8").split("\n").map(item=> item.trim())
  // delete first line
  spec.shift()
  /** @type {Record<string, any>} */
  const v1 = {}
  for (let i = 0; i < spec.length; i++) {
    const line = spec[i]
    if (line.startsWith("///")) {
      const desc = line.replace("///", "").trim()
      const [ _type, _key ] = spec[i + 1].split(" ")
      const key = _key.replace(";", "")
      let type = _type.replace("?", "")
      if (type == "String") {
        type = "string"
      } else if (type == "bool") {
        type = "boolean"
      } else if (type == "int") {
        type = "number"
      }
      v1[key] = {
        type,
        description: desc,
      }
    }
  }
  const cx = {
    $schema: "http://json-schema.org/draft-07/schema#",
    type: "object",
    properties: {
      data: {
        type: "array",
        items: {
          $ref: "#/definitions/v1"
        }
      }
    },
    definitions: {
      v1: {
        type: "object",
        properties: v1,
      },
    },
  }
  fs.writeFileSync("schema/assets.json", JSON.stringify(cx, null, 2))
})()