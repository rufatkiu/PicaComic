import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:pica_comic/network/cache_network.dart';
import 'dart:convert' as convert;
import 'package:pica_comic/network/picacg_network/headers.dart';
import 'package:pica_comic/network/picacg_network/request.dart';
import 'package:pica_comic/network/proxy.dart';
import 'package:pica_comic/views/pic_views/login_page.dart';
import 'package:pica_comic/views/pre_search_page.dart';
import 'package:pica_comic/views/widgets/show_message.dart';
import '../../base.dart';
import '../../foundation/log.dart';
import '../res.dart';
import 'models.dart';

const defaultAvatarUrl = "DEFAULT AVATAR URL"; //历史遗留, 不改了

///哔咔网络请求类
class PicacgNetwork {
  factory PicacgNetwork([String token = ""]) =>
      cache ?? (cache = PicacgNetwork._create(token = token));

  static PicacgNetwork? cache;

  PicacgNetwork._create([this.token = ""]);

  String apiUrl = appdata.settings[3] == "1" || GetPlatform.isWeb
      ? "https://api.kokoiro.xyz/picaapi"
      : "https://picaapi.picacomic.com";
  InitData? initData;
  String token;
  bool status = false; //用于判断请求出错时的情况, true意味着捕获了已知的错误
  String message = ""; //提供错误信息
  bool useCf = false;

  Future<void> updateApi() async {
    if (appdata.settings[3] == "1") {
      useCf = false;
      apiUrl = "https://api.kokoiro.xyz/picaapi";
    } else {
      apiUrl = "https://picaapi.picacomic.com";
    }
  }

  Future<Map<String, dynamic>?> get(String url,
      {CacheExpiredTime expiredTime = CacheExpiredTime.short}) async {
    status = false;
    if (token == "") {
      await Future.delayed(const Duration(milliseconds: 500));
      status = true;
      message = "未登录";
      return null;
    }
    var dio = CachedNetwork();
    var options = getHeaders("get", token, url.replaceAll("$apiUrl/", ""));
    options.validateStatus = (i) => i == 200 || i == 400 || i == 401;

    try {
      var res = await dio.get(url, options, expiredTime: expiredTime);
      if (res.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(res.data) as Map<String, dynamic>;
        return jsonResponse;
      } else if (res.statusCode == 400) {
        status = true;
        var jsonResponse = convert.jsonDecode(res.data) as Map<String, dynamic>;
        message = jsonResponse["message"];
        return null;
      } else if (res.statusCode == 401) {
        appdata.settings[13] = "0";
        appdata.writeData();
        Get.offAll(const LoginPage());
        showMessage(Get.context, "登录失效".tr);
        return null;
      } else {
        return null;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        status = true;
        message = "连接超时";
      } else if (e.type != DioExceptionType.unknown) {
        status = true;
        message = e.message!;
      } else {
        status = true;
        message = e.toString().split("\n")[1];
      }
      return null;
    }
    catch(e, stack){
      LogManager.addLog(LogLevel.error, "Network", "$e\n$stack");
      return null;
    }
  }

  Future<Map<String, dynamic>?> post(String url, Map<String, String>? data) async {
    status = false;
    var api = appdata.settings[3] == "1"
        ? "https://api.kokoiro.xyz/picaapi"
        : "https://picaapi.picacomic.com";
    if (token == "" &&
        url != '$api/auth/sign-in' &&
        url != "https://picaapi.picacomic.com/auth/register") {
      await Future.delayed(const Duration(milliseconds: 500));
      status = true;
      message = "未登录";
      return null;
    }
    var dio = await request();
    dio.options = getHeaders("post", token, url.replaceAll("$apiUrl/", ""));
    try {
      await setNetworkProxy();
      var res = await dio.post(url, data: data, options: Options(validateStatus: (i) {
        return i == 200 || i == 400 || i == 401;
      }));
      if (res.statusCode == 200) {
        var jsonResponse = convert.jsonDecode(res.toString()) as Map<String, dynamic>;
        return jsonResponse;
      } else if (res.statusCode == 400) {
        status = true;
        var jsonResponse = convert.jsonDecode(res.toString()) as Map<String, dynamic>;
        message = jsonResponse["message"];
        return null;
      } else if (res.statusCode == 401) {
        appdata.settings[13] = "0";
        appdata.writeData();
        Get.offAll(const LoginPage());
        showMessage(Get.context, "登录失效".tr);
        return null;
      } else {
        return null;
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        status = true;
        message = "连接超时";
      } else if (e.type != DioExceptionType.unknown) {
        status = true;
        message = e.message!;
      } else {
        status = true;
        message = e.toString().split("\n")[1];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  ///登录
  Future<bool> login(String email, String password) async {
    var api = appdata.settings[3] == "1"
        ? "https://api.kokoiro.xyz/picaapi"
        : "https://picaapi.picacomic.com";
    var res = await post('$api/auth/sign-in', {
      "email": email,
      "password": password,
    });
    if (res != null) {
      if (res["message"] == "success") {
        try {
          token = res["data"]["token"];
        } catch (e) {
          status = true;
          message = "未能获取到token";
          //既然没能拿到token, 那么应该不存在敏感信息, 实在是不清楚为什么没有token, 因此将数据上报
          sendNetworkLog("login", res.toString());
          return false;
        }
        if (kDebugMode) {
          print("Logging successfully");
        }
        return true;
      } else {
        return false;
      }
    } else if (status) {
      return false;
    } else {
      return false;
    }
  }

  ///获取用户信息
  Future<Profile?> getProfile() async {
    var res = await get("$apiUrl/users/profile", expiredTime: CacheExpiredTime.no);
    if (res != null) {
      res = res["data"]["user"];
      String url = "";
      if (res!["avatar"] == null) {
        url = defaultAvatarUrl;
      } else {
        url = res["avatar"]["fileServer"] + "/static/" + res["avatar"]["path"];
      }
      var p = Profile(res["_id"], url, res["email"], res["exp"], res["level"], res["name"],
          res["title"], res["isPunched"], res["slogan"], res["character"]);
      return p;
    } else {
      return null;
    }
  }

  ///获取热搜词
  Future<KeyWords?> getKeyWords() async {
    var res = await get("$apiUrl/keywords", expiredTime: CacheExpiredTime.no);
    if (res != null) {
      var k = KeyWords();
      for (int i = 0; i < (res["data"]["keywords"] ?? []).length; i++) {
        k.keyWords.add(res["data"]["keywords"][i]);
      }
      return k;
    } else {
      return null;
    }
  }

  ///获取分类
  Future<List<CategoryItem>?> getCategories() async {
    var res = await get("$apiUrl/categories");
    if (res != null) {
      try {
        var c = <CategoryItem>[];
        for (int i = 0; i < res["data"]["categories"].length; i++) {
          if (res["data"]["categories"][i]["isWeb"] == true) continue;
          String url = res["data"]["categories"][i]["thumb"]["fileServer"];
          if (url[url.length - 1] != '/') {
            url = '$url/static/';
          }
          url = url + res["data"]["categories"][i]["thumb"]["path"];
          var ca = CategoryItem(res["data"]["categories"][i]["title"], url);
          c.add(ca);
        }
        return c;
      } catch (e, s) {
        LogManager.addLog(LogLevel.error, "Network", "$e\n$s");
        status = true;
        message = e.toString();
        return null;
      }
    } else {
      return null;
    }
  }

  ///获取分流ip
  Future<String?> init() async {
    try {
      var dio = Dio();
      var res = await dio.get("http://68.183.234.72/init");
      var jsonResponse = convert.jsonDecode(res.toString()) as Map<String, dynamic>;
      return jsonResponse["addresses"][0];
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Network", "$e\n$s");
      return null;
    }
  }

  Future<Res<List<ComicItemBrief>>> search(String keyWord, String sort, int page,
      {bool addToHistory = false}) async {
    var res =
        await post('$apiUrl/comics/advanced-search?page=$page', {"keyword": keyWord, "sort": sort});
    if (page == 1 && addToHistory && keyWord != "") {
      appdata.searchHistory.remove(keyWord);
      appdata.searchHistory.add(keyWord);
      appdata.writeHistory();
    }
    if (res != null) {
      try {
        var pages = res["data"]["comics"]["pages"];
        var comics = <ComicItemBrief>[];
        for (int i = 0; i < res["data"]["comics"]["docs"].length; i++) {
          try {
            var tags = [];
            tags.addAll(res["data"]["comics"]["docs"][i]["tags"] ?? []);
            tags.addAll(res["data"]["comics"]["docs"][i]["categories"] ?? []);
            var si = ComicItemBrief(
                res["data"]["comics"]["docs"][i]["title"] ?? "未知",
                res["data"]["comics"]["docs"][i]["author"] ?? "未知",
                int.parse(res["data"]["comics"]["docs"][i]["likesCount"].toString()),
                res["data"]["comics"]["docs"][i]["thumb"]["fileServer"] +
                    "/static/" +
                    res["data"]["comics"]["docs"][i]["thumb"]["path"],
                res["data"]["comics"]["docs"][i]["_id"],
                tags);
            comics.add(si);
          } catch (e) {
            continue;
          }
        }
        if (addToHistory) {
          Future.delayed(const Duration(microseconds: 500), () {
            try {
              Get.find<PreSearchController>().update();
            } catch (e) {
              //忽视
            }
          });
        }
        return Res(comics, subData: pages);
      } catch (e, s) {
        LogManager.addLog(LogLevel.error, "Data Analysis", "$e\n$s");
        return Res(null, errorMessage: e.toString());
      }
    } else {
      return Res(null, errorMessage: status ? message : "网络错误");
    }
  }

  ///获取漫画信息
  Future<ComicItem?> getComicInfo(String id) async {
    var res = await get("$apiUrl/comics/$id", expiredTime: CacheExpiredTime.no);
    if (res != null) {
      String url;
      if (res["data"]["comic"]["_creator"]["avatar"] == null) {
        url = defaultAvatarUrl;
      } else {
        url = res["data"]["comic"]["_creator"]["avatar"]["fileServer"] +
            "/static/" +
            res["data"]["comic"]["_creator"]["avatar"]["path"];
      }
      var creator = Profile(
          res["data"]["comic"]["_id"],
          url,
          "",
          res["data"]["comic"]["_creator"]["exp"],
          res["data"]["comic"]["_creator"]["level"],
          res["data"]["comic"]["_creator"]["name"],
          res["data"]["comic"]["_creator"]["title"] ?? "未知",
          null,
          res["data"]["comic"]["_creator"]["slogan"] ?? "无",
          null);
      var categories = <String>[];
      for (int i = 0; i < res["data"]["comic"]["categories"].length; i++) {
        categories.add(res["data"]["comic"]["categories"][i]);
      }
      var tags = <String>[];
      for (int i = 0; i < res["data"]["comic"]["tags"].length; i++) {
        tags.add(res["data"]["comic"]["tags"][i]);
      }
      var ci = ComicItem(
          creator,
          res["data"]["comic"]["title"] ?? "未知",
          res["data"]["comic"]["description"] ?? "无",
          res["data"]["comic"]["thumb"]["fileServer"] +
                  "/static/" +
                  res["data"]["comic"]["thumb"]["path"] ??
              "",
          res["data"]["comic"]["author"] ?? "未知",
          res["data"]["comic"]["chineseTeam"] ?? "未知",
          categories,
          tags,
          res["data"]["comic"]["likesCount"] ?? 0,
          res["data"]["comic"]["commentsCount"] ?? 0,
          res["data"]["comic"]["isFavourite"] ?? false,
          res["data"]["comic"]["isLiked"] ?? false,
          res["data"]["comic"]["epsCount"] ?? 0,
          id,
          res["data"]["comic"]["pagesCount"],
          res["data"]["comic"]["updated_at"]);
      return ci;
    } else {
      return null;
    }
  }

  Future<List<String>> getEps(String id) async {
    //获取漫画章节信息
    var eps = <String>[];
    int i = 0;
    bool flag = true;
    while (flag) {
      i++;
      var res = await get("$apiUrl/comics/$id/eps?page=$i");
      if (res == null) {
        return eps;
      } else if (res["data"]["eps"]["pages"] == i) {
        flag = false;
      }
      for (int j = 0; j < res["data"]["eps"]["docs"].length; j++) {
        eps.add(res["data"]["eps"]["docs"][j]["title"]);
      }
    }
    eps.add("");
    return eps.reversed.toList();
  }

  Future<List<String>> getComicContent(String id, int order) async {
    //获取漫画内容
    var imageUrls = <String>[];
    int i = 0;
    bool flag = true;
    while (flag) {
      i++;
      var res = await get("$apiUrl/comics/$id/order/$order/pages?page=$i");
      if (res == null) {
        return imageUrls;
      } else if (res["data"]["pages"]["pages"] == i) {
        flag = false;
      }
      for (int j = 0; j < res["data"]["pages"]["docs"].length; j++) {
        imageUrls.add(res["data"]["pages"]["docs"][j]["media"]["fileServer"] +
            "/static/" +
            res["data"]["pages"]["docs"][j]["media"]["path"]);
      }
    }
    return imageUrls;
  }

  Future<void> loadMoreCommends(Comments c, {String type = "comics"}) async {
    if (c.loaded != c.pages) {
      var res = await get("$apiUrl/$type/${c.id}/comments?page=${c.loaded + 1}",
          expiredTime: CacheExpiredTime.no);
      if (res != null) {
        c.pages = res["data"]["comments"]["pages"];
        for (int i = 0; i < res["data"]["comments"]["docs"].length; i++) {
          String url = "";
          try {
            url = res["data"]["comments"]["docs"][i]["_user"]["avatar"]["fileServer"] +
                "/static/" +
                res["data"]["comments"]["docs"][i]["_user"]["avatar"]["path"];
          } catch (e) {
            url = defaultAvatarUrl;
          }
          var t = Comment("", "", "", 1, "", 0, "", false, 0, null, null, "");
          if (res["data"]["comments"]["docs"][i]["_user"] != null) {
            t = Comment(
                res["data"]["comments"]["docs"][i]["_user"]["name"],
                url,
                res["data"]["comments"]["docs"][i]["_user"]["_id"],
                res["data"]["comments"]["docs"][i]["_user"]["level"],
                res["data"]["comments"]["docs"][i]["content"],
                res["data"]["comments"]["docs"][i]["commentsCount"],
                res["data"]["comments"]["docs"][i]["_id"],
                res["data"]["comments"]["docs"][i]["isLiked"],
                res["data"]["comments"]["docs"][i]["likesCount"],
                res["data"]["comments"]["docs"][i]["_user"]["character"],
                res["data"]["comments"]["docs"][i]["_user"]["slogan"],
                res["data"]["comments"]["docs"][i]["created_at"]);
          } else {
            t = Comment(
                "未知",
                url,
                "",
                1,
                res["data"]["comments"]["docs"][i]["content"],
                res["data"]["comments"]["docs"][i]["commentsCount"],
                res["data"]["comments"]["docs"][i]["_id"],
                res["data"]["comments"]["docs"][i]["isLiked"],
                res["data"]["comments"]["docs"][i]["likesCount"],
                null,
                null,
                res["data"]["comments"]["docs"][i]["created_at"]);
          }
          c.comments.add(t);
        }
        c.loaded++;
      }
    }
  }

  Future<Comments> getCommends(String id, {String type = "comics"}) async {
    var t = Comments([], id, 1, 0);
    await loadMoreCommends(t, type: type);
    return t;
  }

  Future<Res<List<ComicItemBrief>>> getFavorites(int page) async {
    var res =
        await get("$apiUrl/users/favourite?s=dd&page=$page", expiredTime: CacheExpiredTime.no);
    if (res != null) {
      try {
        var pages = res["data"]["comics"]["pages"];
        var comics = <ComicItemBrief>[];
        for (int i = 0; i < res["data"]["comics"]["docs"].length; i++) {
          var si = ComicItemBrief(
              res["data"]["comics"]["docs"][i]["title"] ?? "未知",
              res["data"]["comics"]["docs"][i]["author"] ?? "未知",
              int.parse(res["data"]["comics"]["docs"][i]["likesCount"].toString()),
              res["data"]["comics"]["docs"][i]["thumb"]["fileServer"] +
                  "/static/" +
                  res["data"]["comics"]["docs"][i]["thumb"]["path"],
              res["data"]["comics"]["docs"][i]["_id"],
              [],
              ignoreExamination: true);
          comics.add(si);
        }
        return Res(comics, subData: pages);
      } catch (e, s) {
        LogManager.addLog(LogLevel.error, "Data Analysis", "$e\n$s");
        return Res(null, errorMessage: e.toString());
      }
    } else {
      return Res(null, errorMessage: status ? message : "网络错误");
    }
  }

  Future<int> getSelectedPageFavorites(int page, List<ComicItemBrief> comics) async {
    var res = await get("$apiUrl/users/favourite?s=dd&page=$page");
    comics.clear();
    if (res != null) {
      for (int i = 0; i < res["data"]["comics"]["docs"].length; i++) {
        var si = ComicItemBrief(
            res["data"]["comics"]["docs"][i]["title"] ?? "未知",
            res["data"]["comics"]["docs"][i]["author"] ?? "未知",
            int.parse(res["data"]["comics"]["docs"][i]["likesCount"].toString()),
            res["data"]["comics"]["docs"][i]["thumb"]["fileServer"] +
                "/static/" +
                res["data"]["comics"]["docs"][i]["thumb"]["path"],
            res["data"]["comics"]["docs"][i]["_id"],
            [],
            ignoreExamination: true);
        comics.add(si);
      }
    }
    return res == null ? 0 : res["data"]["comics"]["pages"];
  }

  Future<List<ComicItemBrief>> getRandomComics() async {
    var comics = <ComicItemBrief>[];
    var res = await get("$apiUrl/comics/random", expiredTime: CacheExpiredTime.no);
    if (res != null) {
      for (int i = 0; i < res["data"]["comics"].length; i++) {
        try {
          var tags = [];
          tags.addAll(res["data"]["comics"][i]["tags"] ?? []);
          tags.addAll(res["data"]["comics"][i]["categories"] ?? []);
          var si = ComicItemBrief(
            res["data"]["comics"][i]["title"] ?? "未知",
            res["data"]["comics"][i]["author"] ?? "未知",
            res["data"]["comics"][i]["totalLikes"] ?? 0,
            res["data"]["comics"][i]["thumb"]["fileServer"] +
                "/static/" +
                res["data"]["comics"][i]["thumb"]["path"],
            res["data"]["comics"][i]["_id"],
            tags,
          );
          comics.add(si);
        } catch (e) {
          //出现错误跳过
        }
      }
    }
    return comics;
  }

  Future<bool> likeOrUnlikeComic(String id) async {
    var res = await post('$apiUrl/comics/$id/like', {});
    if (res != null) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> favouriteOrUnfavoriteComic(String id) async {
    var res = await post('$apiUrl/comics/$id/favourite', {});
    if (res == null) {
      showMessage(Get.context, "网络错误".tr);
      return false;
    }
    showMessage(Get.context, (res["data"]["action"] == "favourite") ? "添加收藏成功".tr : "取消收藏成功".tr);
    return true;
  }

  Future<List<ComicItemBrief>> getLeaderboard(String time) async {
    /*
    Time:
      H24 过去24小时
      D7 过去7天
      D30 过去30天
     */
    var res =
        await get("$apiUrl/comics/leaderboard?tt=$time&ct=VC", expiredTime: CacheExpiredTime.no);
    var comics = <ComicItemBrief>[];
    if (res != null) {
      for (int i = 0; i < res["data"]["comics"].length; i++) {
        try {
          var tags = [];
          tags.addAll(res["data"]["comics"][i]["tags"] ?? []);
          tags.addAll(res["data"]["comics"][i]["categories"] ?? []);
          var si = ComicItemBrief(
              res["data"]["comics"][i]["title"] ?? "未知",
              res["data"]["comics"][i]["author"] ?? "未知",
              res["data"]["comics"][i]["totalLikes"] ?? 0,
              res["data"]["comics"][i]["thumb"]["fileServer"] +
                  "/static/" +
                  res["data"]["comics"][i]["thumb"]["path"],
              res["data"]["comics"][i]["_id"],
              tags);
          comics.add(si);
        } catch (e) {
          //出现错误跳过}
        }
      }
    }
    return comics;
  }

  Future<Res<String>> register(
      String ans1,
      String ans2,
      String ans3,
      String birthday,
      String account,
      String gender,
      String name,
      String password,
      String que1,
      String que2,
      String que3) async {
    //gender:m,f,bot
    var res = await post("https://picaapi.picacomic.com/auth/register", {
      "answer1": ans1,
      "answer2": ans2,
      "answer3": ans3,
      "birthday": birthday,
      "email": account,
      "gender": gender,
      "name": name,
      "password": password,
      "question1": que1,
      "question2": que2,
      "question3": que3
    });
    if (res == null) {
      return Res(null, errorMessage: status ? message : "网络错误");
    } else if (res["message"] == "failure") {
      return Res(null, errorMessage: "注册失败, 用户名或账号可能已存在");
    } else {
      return Res("注册成功");
    }
  }

  Future<bool> punchIn() async {
    //打卡
    var res = await post("$apiUrl/users/punch-in", null);
    if (res != null) {
      return true;
    } else {
      return false;
    }
  }

  Future<bool> uploadAvatar(String imageData) async {
    //上传头像
    //数据仍然是json, 只有一条"avatar"数据, 数据内容为base64编码的图像, 例如{"avatar":"[在这里放图像数据]"}
    var url = "$apiUrl/users/avatar";
    var dio = await request();
    dio.options = getHeaders("put", token, url.replaceAll("$apiUrl/", ""));
    try {
      var res = await dio.put(url, data: {"avatar": imageData});
      return res.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> changeSlogan(String slogan) async {
    var url = "$apiUrl/users/profile";
    var dio = await request();
    dio.options = getHeaders("put", token, url.replaceAll("$apiUrl/", ""));
    try {
      var res = await dio.put(url, data: {"slogan": slogan});
      if (res.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> getMoreReply(Reply reply) async {
    if (reply.loaded == reply.total) return;
    var res = await get("$apiUrl/comments/${reply.id}/childrens?page=${reply.loaded + 1}",
        expiredTime: CacheExpiredTime.no); //哔咔的英语水平有点烂
    if (res != null) {
      reply.total = res["data"]["comments"]["pages"];
      for (int i = 0; i < res["data"]["comments"]["docs"].length; i++) {
        String url = "";
        try {
          url = res["data"]["comments"]["docs"][i]["_user"]["avatar"]["fileServer"] +
              "/static/" +
              res["data"]["comments"]["docs"][i]["_user"]["avatar"]["path"];
        } catch (e) {
          url = defaultAvatarUrl;
        }
        var t = Comment("", "", "", 1, "", 0, "", false, 0, null, null, "");
        if (res["data"]["comments"]["docs"][i]["_user"] != null) {
          t = Comment(
              res["data"]["comments"]["docs"][i]["_user"]["name"] ?? "未知",
              url,
              res["data"]["comments"]["docs"][i]["_user"]["_id"] ?? "",
              res["data"]["comments"]["docs"][i]["_user"]["level"] ?? 0,
              res["data"]["comments"]["docs"][i]["content"] ?? "",
              0,
              "",
              res["data"]["comments"]["docs"][i]["isLiked"],
              res["data"]["comments"]["docs"][i]["likesCount"] ?? 0,
              res["data"]["comments"]["docs"][i]["_user"]["character"],
              res["data"]["comments"]["docs"][i]["_user"]["slogan"] ?? "",
              res["data"]["comments"]["docs"][i]["created_at"]);
        } else {
          t = Comment(
              "未知",
              url,
              "",
              1,
              res["data"]["comments"]["docs"][i]["content"],
              0,
              "",
              res["data"]["comments"]["docs"][i]["isLiked"],
              res["data"]["comments"]["docs"][i]["likesCount"],
              null,
              null,
              res["data"]["comments"]["docs"][i]["created_at"]);
        }
        reply.comments.add(t);
      }
      reply.loaded++;
    }
  }

  Future<Reply> getReply(String id) async {
    var reply = Reply(id, 0, 1, []);
    await getMoreReply(reply);
    return reply;
  }

  Future<bool> likeOrUnlikeComment(String id) async {
    var res = await post("$apiUrl/comments/$id/like", {});
    return res != null;
  }

  Future<bool> comment(String id, String text, bool isReply, {String type = "comics"}) async {
    Map<String, dynamic>? res;
    if (!isReply) {
      res = await post("$apiUrl/$type/$id/comments", {"content": text});
    } else {
      res = await post("$apiUrl/comments/$id", {"content": text});
    }
    return res != null;
  }

  Future<List<ComicItemBrief>> getRecommendation(String id) async {
    var comics = <ComicItemBrief>[];
    var res = await get("$apiUrl/comics/$id/recommendation");
    if (res != null) {
      for (int i = 0; i < res["data"]["comics"].length; i++) {
        try {
          var si = ComicItemBrief(
              res["data"]["comics"][i]["title"] ?? "未知",
              res["data"]["comics"][i]["author"] ?? "未知",
              int.parse(res["data"]["comics"][i]["likesCount"].toString()),
              res["data"]["comics"][i]["thumb"]["fileServer"] +
                  "/static/" +
                  res["data"]["comics"][i]["thumb"]["path"],
              res["data"]["comics"][i]["_id"],
              [],
              ignoreExamination: true);
          comics.add(si);
        } catch (e) {
          //出现错误跳过
        }
      }
    }
    return comics;
  }

  Future<List<List<ComicItemBrief>>?> getCollection() async {
    var comics = <List<ComicItemBrief>>[[], []];
    var res = await get("$apiUrl/collections", expiredTime: CacheExpiredTime.no);
    if (res != null) {
      try {
        for (int i = 0; i < res["data"]["collections"][0]["comics"].length; i++) {
          try {
            var si = ComicItemBrief(
                res["data"]["collections"][0]["comics"][i]["title"] ?? "未知",
                res["data"]["collections"][0]["comics"][i]["author"] ?? "未知",
                res["data"]["collections"][0]["comics"][i]["totalLikes"] ?? 0,
                res["data"]["collections"][0]["comics"][i]["thumb"]["fileServer"] +
                    "/static/" +
                    res["data"]["collections"][0]["comics"][i]["thumb"]["path"],
                res["data"]["collections"][0]["comics"][i]["_id"],
                [],
                ignoreExamination: true);
            comics[0].add(si);
          } catch (e) {
            //出现错误跳过
          }
        }
      } catch (e) {
        //跳过
      }
      try {
        for (int i = 0; i < res["data"]["collections"][1]["comics"].length; i++) {
          try {
            var si = ComicItemBrief(
                res["data"]["collections"][1]["comics"][i]["title"] ?? "未知",
                res["data"]["collections"][1]["comics"][i]["author"] ?? "未知",
                res["data"]["collections"][1]["comics"][i]["totalLikes"] ?? 0,
                res["data"]["collections"][1]["comics"][i]["thumb"]["fileServer"] +
                    "/static/" +
                    res["data"]["collections"][1]["comics"][i]["thumb"]["path"],
                res["data"]["collections"][1]["comics"][i]["_id"],
                [],
                ignoreExamination: true);
            comics[1].add(si);
          } catch (e) {
            //出现错误跳过}
          }
        }
      } catch (e) {
        //跳过
      }
    } else {
      return null;
    }
    return comics;
  }

  Future<void> getMoreGames(Games games) async {
    if (games.total == games.loaded) return;
    var res = await get("$apiUrl/games?page=${games.loaded + 1}", expiredTime: CacheExpiredTime.no);
    if (res != null) {
      games.total = res["data"]["games"]["pages"];
      for (int i = 0; i < res["data"]["games"]["docs"].length; i++) {
        var game = GameItemBrief(
            res["data"]["games"]["docs"][i]["_id"] ?? "",
            res["data"]["games"]["docs"][i]["title"] ?? "未知",
            res["data"]["games"]["docs"][i]["adult"],
            res["data"]["games"]["docs"][i]["icon"]["fileServer"] +
                "/static/" +
                res["data"]["games"]["docs"][i]["icon"]["path"],
            res["data"]["games"]["docs"][i]["publisher"] ?? "未知");
        games.games.add(game);
      }
    }
    games.loaded++;
  }

  Future<Games> getGames() async {
    var games = Games([], 0, 1);
    await getMoreGames(games);
    return games;
  }

  Future<GameInfo?> getGameInfo(String id) async {
    var res = await get("$apiUrl/games/$id");
    if (res != null) {
      var gameInfo = GameInfo(
          id,
          res["data"]["game"]["title"] ?? "未知",
          res["data"]["game"]["description"],
          res["data"]["game"]["icon"]["fileServer"] +
              "/static/" +
              res["data"]["game"]["icon"]["path"],
          res["data"]["game"]["publisher"],
          [],
          res["data"]["game"]["androidLinks"][0],
          res["data"]["game"]["isLiked"],
          res["data"]["game"]["likesCount"],
          res["data"]["game"]["commentsCount"]);
      for (int i = 0; i < res["data"]["game"]["screenshots"].length; i++) {
        gameInfo.screenshots.add(res["data"]["game"]["screenshots"][i]["fileServer"] +
            "/static/" +
            res["data"]["game"]["screenshots"][i]["path"]);
      }
      return gameInfo;
    } else {
      return null;
    }
  }

  Future<bool> likeGame(String id) async {
    var res = await post("$apiUrl/games/$id/like", {});
    return res != null;
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    status = false;
    var url = "$apiUrl/users/password";
    var dio = await request();
    dio.options = getHeaders("put", token, url.replaceAll("$apiUrl/", ""));
    try {
      var res =
          await dio.put(url, data: {"new_password": newPassword, "old_password": oldPassword});
      return res.statusCode == 200;
    } on DioException catch (e) {
      if (e.message == "Http status error [400]") {
        status = true;
        return false;
      } else {
        return false;
      }
    } catch (e, s) {
      LogManager.addLog(LogLevel.error, "Network", "$e\n$s");
      return false;
    }
  }

  Future<Res<List<ComicItemBrief>>> getCategoryComics(String keyWord, int page, String sort) async {
    var res = await get('$apiUrl/comics?page=$page&c=${Uri.encodeComponent(keyWord)}&s=$sort',
        expiredTime: CacheExpiredTime.no);
    if (res != null) {
      var pages = res["data"]["comics"]["pages"];
      var comics = <ComicItemBrief>[];
      for (int i = 0; i < res["data"]["comics"]["docs"].length; i++) {
        try {
          var tags = [];
          tags.addAll(res["data"]["comics"]["docs"][i]["tags"] ?? []);
          tags.addAll(res["data"]["comics"]["docs"][i]["categories"] ?? []);
          var si = ComicItemBrief(
              res["data"]["comics"]["docs"][i]["title"] ?? "未知",
              res["data"]["comics"]["docs"][i]["author"] ?? "未知",
              int.parse(res["data"]["comics"]["docs"][i]["likesCount"].toString()),
              res["data"]["comics"]["docs"][i]["thumb"]["fileServer"] +
                  "/static/" +
                  res["data"]["comics"]["docs"][i]["thumb"]["path"],
              res["data"]["comics"]["docs"][i]["_id"],
              tags);
          comics.add(si);
        } catch (e) {
          continue;
        }
      }
      return Res(comics, subData: pages);
    } else {
      return Res(null, errorMessage: status ? message : "网络错误");
    }
  }

  ///获取最新漫画
  Future<Res<List<ComicItemBrief>>> getLatest(int page) async {
    var res = await get("$apiUrl/comics?page=$page&s=dd", expiredTime: CacheExpiredTime.no);
    if (res == null) {
      return Res(null, errorMessage: status ? message : "网络错误");
    } else {
      var comics = <ComicItemBrief>[];
      for (int i = 0; i < res["data"]["comics"]["docs"].length; i++) {
        try {
          var tags = [];
          tags.addAll(res["data"]["comics"]["docs"][i]["tags"] ?? []);
          tags.addAll(res["data"]["comics"]["docs"][i]["categories"] ?? []);

          var si = ComicItemBrief(
            res["data"]["comics"]["docs"][i]["title"] ?? "未知",
            res["data"]["comics"]["docs"][i]["author"] ?? "未知",
            int.parse(res["data"]["comics"]["docs"][i]["likesCount"].toString()),
            res["data"]["comics"]["docs"][i]["thumb"]["fileServer"] +
                "/static/" +
                res["data"]["comics"]["docs"][i]["thumb"]["path"],
            res["data"]["comics"]["docs"][i]["_id"],
            tags,
          );
          comics.add(si);
        } catch (e) {
          continue;
        }
      }
      return Res(comics);
    }
  }
}

String getImageUrl(String url) {
  return appdata.settings[3] == "1" || GetPlatform.isWeb
      ? "https://api.kokoiro.xyz/storage/$url"
      : url;
}

var network = PicacgNetwork();
