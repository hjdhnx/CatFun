/// 源列表导入列表, 一般来说是 waifu-project/assets 仓库维护的 .json 文件
class AssetSourceItemJSONData {
  /// 源名称
  String? title;

  /// 采集地址, 一般是地址合集
  String? url;

  /// 源的说明, 一般是导入的时候用来提示的
  String? msg;

  /// 是否是 18+ 的源
  bool? nsfw;

  AssetSourceItemJSONData({
    this.title,
    this.url,
    this.msg,
    this.nsfw,
  });

  AssetSourceItemJSONData.fromJson(Map<String, dynamic> json) {
    title = json['title'];
    url = json['url'];
    msg = json['msg'];
    nsfw = json['nsfw'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['title'] = title;
    data['url'] = url;
    data['msg'] = msg;
    data['nsfw'] = nsfw;
    return data;
  }
}
