import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:pica_comic/network/new_download.dart';
import 'package:pica_comic/network/picacg_network/methods.dart';
import 'package:pica_comic/network/picacg_network/models.dart';
import 'package:pica_comic/foundation/ui_mode.dart';
import 'package:pica_comic/views/pic_views/category_comic_page.dart';
import 'package:pica_comic/views/reader/comic_reading_page.dart';
import 'package:pica_comic/views/pic_views/comments_page.dart';
import 'package:pica_comic/views/reader/goto_reader.dart';
import 'package:pica_comic/views/show_image_page.dart';
import 'package:pica_comic/views/widgets/avatar.dart';
import 'package:pica_comic/views/widgets/loading.dart';
import 'package:pica_comic/views/widgets/selectable_text.dart';
import 'package:pica_comic/views/widgets/show_error.dart';
import 'package:pica_comic/views/widgets/side_bar.dart';
import 'package:pica_comic/views/pic_views/widgets.dart';
import 'package:pica_comic/base.dart';
import 'package:share_plus/share_plus.dart';
import '../widgets/select_download_eps.dart';
import 'package:pica_comic/views/widgets/show_message.dart';

class ComicPageLogic extends GetxController{
  bool isLoading = true;
  ComicItem? comicItem;
  bool underReview = false;
  bool noNetwork = false;
  bool showAppbarTitle = false;
  var tags = <Widget>[];
  var categories = <Widget>[];
  var recommendation = <ComicItemBrief>[];
  var controller = ScrollController();
  var eps = <Widget>[
    ListTile(
      leading: const Icon(Icons.library_books),
      title: Text("章节".tr),
    ),
  ];
  var epsStr = <String>[""];
  void change(){
    isLoading = !isLoading;
    update();
  }
}

class ComicPage extends StatelessWidget{
  final ComicItemBrief comic;
  final bool downloaded;
  const ComicPage(this.comic,{super.key, this.downloaded=false});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: GetBuilder<ComicPageLogic>(
        tag: comic.id,
        init: ComicPageLogic(),
        builder: (logic){
          //检查是否下载
        if(downloaded){
          logic.isLoading = false;
        }

        if(logic.isLoading){
          //加载漫画信息
          loadComicInfo(logic, context);
          //返回加载页面
          return showLoading(context);
        }else if(logic.comicItem!=null){
          //成功获取到了漫画信息
          logic.controller = ScrollController();
          logic.controller.addListener(() {
            //检测当前滚动位置, 决定是否显示Appbar的标题
            bool temp = logic.showAppbarTitle;
            if(! logic.controller.hasClients) return;
            logic.showAppbarTitle = logic.controller.position.pixels>
                boundingTextSize(
                    comic.title,
                    const TextStyle(fontSize: 22),
                    maxWidth: width
                ).height+50;
            if(temp!=logic.showAppbarTitle) {
              logic.update();
            }
          });

          return CustomScrollView(
            controller: logic.controller,
            slivers: [
              SliverAppBar(
                surfaceTintColor: logic.showAppbarTitle?null:Colors.transparent,
                shadowColor: Colors.transparent,
                title: AnimatedOpacity(
                  opacity: logic.showAppbarTitle?1.0:0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text("${comic.title}(${logic.comicItem!.pagesCount}P)"),
                ),
                pinned: true,
                actions: [
                  Tooltip(
                    message: "分享".tr,
                    child: IconButton(
                      icon: const Icon(Icons.share,),
                      onPressed: () {
                        Share.share(comic.title);
                      },
                    ),)
                ],
              ),

              //标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 15),
                  child: SizedBox(
                    width: double.infinity,
                    child: SelectableTextCN(
                      text: "${comic.title}(${logic.comicItem!.pagesCount}P)",
                      style: const TextStyle(fontSize: 28),
                      withAddToBlockKeywordButton: true,
                    ),
                  ),
                ),
              ),

              //漫画信息
              buildComicInfo(logic, context),

              const SliverPadding(padding: EdgeInsets.all(5)),

              //章节显示
              ...buildChapterDisplay(context, logic),

              //简介
              const SliverPadding(padding: EdgeInsets.all(5)),
              const SliverToBoxAdapter(child: Divider(),),
              SliverToBoxAdapter(child: SizedBox(width: 100,child: Row(children: [
                const SizedBox(width: 20,),
                Icon(Icons.insert_drive_file, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 20,),
                Text("简介".tr,style: const TextStyle(fontWeight: FontWeight.w500,fontSize: 16),)
              ],)),),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 0, 0),
                  child: SelectableTextCN(text:logic.comicItem!.description),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.all(5)),

              //相关推荐
              if(!downloaded)
              const SliverToBoxAdapter(child: Divider(),),
              if(!downloaded)
              SliverToBoxAdapter(child: SizedBox(width: 100,child: Row(children: [
                const SizedBox(width: 20,),
                Icon(Icons.recommend, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 20,),
                Text("相关推荐".tr,style: const TextStyle(fontWeight: FontWeight.w500,fontSize: 16),)
              ],)),),
              if(!downloaded)
              const SliverPadding(padding: EdgeInsets.all(5)),
              if(!downloaded)
              SliverGrid(
                delegate: SliverChildBuilderDelegate(
                    childCount: logic.recommendation.length,
                        (context, i){
                      return PicComicTile(logic.recommendation[i]);
                    }
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: comicTileMaxWidth,
                  childAspectRatio: comicTileAspectRatio,
                ),
              ),
              if(!downloaded)
              const SliverPadding(padding: EdgeInsets.all(10)),
              SliverPadding(padding: EdgeInsets.only(top: Get.bottomBarHeight))
            ],
          );
        }else{
          //查询是否已经下载
          if(downloadManager.downloaded.contains(comic.id)){
            loadComicInfoFormFile(logic, context);
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          //未能加载漫画信息显示网络错误
          return showNetworkError(network.status?network.message:"网络错误".tr,
                  ()=>logic.change(), context);
        }
      }),
    );
  }

  void loadComicInfo(ComicPageLogic logic, BuildContext context){
    network.getComicInfo(comic.id).then((c) {
      if(network.status){
        logic.underReview = true;
        logic.change();
        return;
      }
      if (c != null) {
        logic.comicItem = c;
        for (String s in c.tags) {
          logic.tags.add(buildInfoCard(s, context));
        }
        for (String s in c.categories) {
          logic.categories.add(buildInfoCard(s, context));
        }
        bool flag1 = false;
        bool flag2 = false;
        network.getRecommendation(comic.id).then((r){
          logic.recommendation = r;
          flag1 = true;
          if(flag1&&flag2){
            logic.change();
          }
        });
        network.getEps(comic.id).then((e) {
          for (int i = 1; i < e.length; i++) {
            logic.epsStr.add(e[i]);
            logic.eps.add(ListTile(
              title: Text(e[i]),
              onTap: () {
                Get.to(() =>
                    ComicReadingPage.picacg(comic.id, i, logic.epsStr, comic.title));
              },
            ));
          }
          flag2 = true;
          if(flag1&&flag2){
            logic.change();
          }
        });
      } else {
        logic.change();
      }
    });
  }

  Widget buildComicInfo(ComicPageLogic logic, BuildContext context){
    if(UiMode.m1(context)) {
      return SliverToBoxAdapter(
        child: SizedBox(
          width: MediaQuery.of(context).size.width/2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              //封面
              buildCover(context, logic, 350, MediaQuery.of(context).size.width),

              const SizedBox(height: 20,),

              ...buildInfoCards(logic, context),
            ],
          ),
        ),
      );
    }
    else {
      return SliverToBoxAdapter(child: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Row(
          children: [
            //封面
            buildCover(context, logic, 550, MediaQuery.of(context).size.width/2),
            SizedBox(
              width: MediaQuery.of(context).size.width/2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: buildInfoCards(logic, context),
              ),
            ),
          ],
        ),
      ),);
    }
  }

  Widget buildCover(BuildContext context, ComicPageLogic logic, double height, double width){
    return downloaded?Image.file(
      downloadManager.getCover(comic.id),
      width: width,
      height: height,
    ):GestureDetector(
      child: CachedNetworkImage(
        width: width,
        height: height,
        imageUrl: getImageUrl(comic.path),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      ),
      onTap: ()=>Get.to(()=>ShowImagePage(comic.path)),
    );
  }

  List<Widget> buildInfoCards(ComicPageLogic logic, BuildContext context){
    var res = <Widget>[];
    var res2 = <Widget>[];

    if(!downloaded) {
      res2.add(Padding(
        padding: const EdgeInsets.fromLTRB(30, 10, 30, 10),
        child: Row(
          children: [
            Expanded(child: ActionChip(
              label: Text(logic.comicItem!.likes.toString()),
              avatar: Icon((logic.comicItem!.isLiked)?Icons.favorite:Icons.favorite_border),
              onPressed: (){
                network.likeOrUnlikeComic(comic.id);
                logic.comicItem!.isLiked = !logic.comicItem!.isLiked;
                logic.update();
              },
            ),),
            SizedBox.fromSize(size: const Size(10,1),),
            Expanded(child: ActionChip(
              label: Text("收藏".tr),
              avatar: Icon((logic.comicItem!.isFavourite)?Icons.bookmark:Icons.bookmark_outline),
              onPressed: (){
                network.favouriteOrUnfavoriteComic(comic.id);
                logic.comicItem!.isFavourite = !logic.comicItem!.isFavourite;
                logic.update();
              },
            ),),
            SizedBox.fromSize(size: const Size(10,1),),
            Expanded(child: ActionChip(
              label: Text(logic.comicItem!.comments.toString()),
              avatar: const Icon(Icons.comment_outlined),
              onPressed: (){
                showComments(context, comic.id);
              },
            ),),
          ],
        ),
      ));
    }

    res2.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Row(
        children: [
          Expanded(child: FilledButton(
            onPressed: (){
              downloadComic(logic.comicItem!, context, logic.epsStr);
            },
            child: (downloadManager.downloaded.contains(comic.id))?Text("修改".tr):Text("下载".tr),
          ),),
          SizedBox.fromSize(size: const Size(10,1),),
          Expanded(child: FilledButton(
            onPressed: () => readPicacgComic(logic.comicItem!, logic.epsStr),
            child: Text("阅读".tr),
          ),),
        ],
      ),
    ));

    if(appdata.firstUse[2]=="1") {
      res.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: MaterialBanner(
            elevation: 1,
            content: Text("要复制或者屏蔽这些关键词, 请长按或者使用鼠标右键".tr),
            actions: [
              TextButton(onPressed: (){
                appdata.firstUse[2] = "0";
                logic.update();
                appdata.writeData();
              }, child: Text("关闭".tr))
            ]),
      ));
    }

    if(logic.comicItem!.author!=""){
      res.add(const SizedBox(
        height: 20,
        child: Text("      作者"),
      ));
    }

    if(logic.comicItem!.author!=""){
      res.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 10, 10),
          child: buildInfoCard(logic.comicItem!.author, context)
      ));
    }

    if(logic.comicItem!.chineseTeam!=""){
      res.add(SizedBox(
        height: 20,
        child: Text("      汉化组".tr),
      ));
    }

    if(logic.comicItem!.chineseTeam!="") {
      res.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 10, 10),
          child: buildInfoCard(logic.comicItem!.chineseTeam, context)
      ));
    }

    res.add(SizedBox(
      height: 20,
      child: Text("      分类".tr),
    ));

    res.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 10, 10),
      child: Wrap(
        children: logic.categories,
      ),
    ));

    res.add(SizedBox(
      height: 20,
      child: Text("      标签".tr),
    ));

    res.add(Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 10, 10),
      child: Wrap(
        children: logic.tags,
      ),
    ));

    if(!downloaded) {
      res.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
        child: Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.inversePrimary,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                Expanded(
                  flex: 0,
                  child: Avatar(
                    size: 50,
                    avatarUrl: logic.comicItem!.creator.avatarUrl,
                    frame: logic.comicItem!.creator.frameUrl,
                    couldBeShown: true,
                    name: logic.comicItem!.creator.name,
                    slogan: logic.comicItem!.creator.slogan,
                    level: logic.comicItem!.creator.level,
                  ),),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(15, 10, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          logic.comicItem!.creator.name,
                          style: const TextStyle(fontSize: 15,fontWeight: FontWeight.w600),
                        ),
                        Text("${logic.comicItem!.time.substring(0,10)} ${logic.comicItem!.time.substring(11,19)}更新")
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
    }

    return !UiMode.m1(context)?res+res2:res2+res;
  }

  List<Widget> buildChapterDisplay(BuildContext context, ComicPageLogic logic){
    return [
      const SliverToBoxAdapter(child: Divider(),),
      SliverToBoxAdapter(child: SizedBox(width: 100,child: Row(children: [
        const SizedBox(width: 20,),
        Icon(Icons.library_books, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 20,),
        Text("章节".tr,style: const TextStyle(fontWeight: FontWeight.w500,fontSize: 16),)
      ],)),),
      const SliverPadding(padding: EdgeInsets.all(5)),
      SliverGrid(
        delegate: SliverChildBuilderDelegate(
            childCount: logic.epsStr.length-1,
                (context, i){
              return Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),child: InkWell(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: Card(
                  elevation: 1,
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  margin: EdgeInsets.zero,
                  child: Center(child: Text(logic.epsStr[i+1]),),
                ),
                onTap: () {
                  addPicacgHistory(logic.comicItem!);
                  Get.to(() =>
                      ComicReadingPage.picacg(comic.id, i+1, logic.epsStr, comic.title));
                },
              ),);
            }
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 250,
          childAspectRatio: 4,
        ),
      ),
    ];
  }

  void loadComicInfoFormFile(ComicPageLogic logic, BuildContext context){
    //加载已下载的漫画
    downloadManager.getComicFromId(comic.id).then((downloadComic){
      logic.isLoading = false;
      logic.comicItem = downloadComic.comicItem;
      for (String s in logic.comicItem!.tags) {
        logic.tags.add(buildInfoCard(s, context));
      }
      for (String s in logic.comicItem!.categories) {
        logic.categories.add(buildInfoCard(s, context));
      }

      for (int i = 1; i < downloadComic.chapters.length; i++) {
        logic.epsStr.add(downloadComic.chapters[i]);
        logic.eps.add(ListTile(
          title: Text(downloadComic.chapters[i]),
          onTap: () {
            Get.to(() =>
                ComicReadingPage.picacg(comic.id, i, logic.epsStr, comic.title));
          },
        ));
      }

      logic.comicItem!.likes = 0;
      logic.comicItem!.comments = 0;
      logic.noNetwork = true;
      logic.update();
    });
  }

  Widget buildInfoCard(String title, BuildContext context){
    return GestureDetector(
      onLongPressStart: (details){
        showMenu(
            context: context,
            position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, details.globalPosition.dx, details.globalPosition.dy),
            items: [
              PopupMenuItem(
                child: Text("复制".tr),
                onTap: (){
                  Clipboard.setData(ClipboardData(text: (title)));
                  showMessage(context, "已复制".tr);
                },
              ),
              PopupMenuItem(
                child: Text("添加到屏蔽词".tr),
                onTap: (){
                  appdata.blockingKeyword.add(title);
                  appdata.writeData();
                },
              ),
            ]
        );
      },
      child: Card(
        margin: const EdgeInsets.fromLTRB(5, 5, 5, 5),
        elevation: 0,
        color: Theme
            .of(context)
            .colorScheme
            .primaryContainer,
        child: InkWell(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          onTap: ()=>Get.to(() => CategoryComicPage(title),preventDuplicates: false),
          onSecondaryTapDown: (details){
            showMenu(
                context: context,
                position: RelativeRect.fromLTRB(details.globalPosition.dx, details.globalPosition.dy, details.globalPosition.dx, details.globalPosition.dy),
                items: [
                  PopupMenuItem(
                    child: Text("复制".tr),
                    onTap: (){
                      Clipboard.setData(ClipboardData(text: (title)));
                      showMessage(context, "已复制".tr);
                    },
                  ),
                  PopupMenuItem(
                    child: Text("添加到屏蔽词".tr),
                    onTap: (){
                      appdata.blockingKeyword.add(title);
                      appdata.writeData();
                    },
                  ),
                ]
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 5), child: Text(title),
          ),
        ),
      ),
    );
  }

  Size boundingTextSize(String text, TextStyle style,  {int maxLines = 2^31, double maxWidth = double.infinity}) {
    if (text.isEmpty) {
      return Size.zero;
    }
    final TextPainter textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(text: text, style: style), maxLines: maxLines)
      ..layout(maxWidth: maxWidth);
    return textPainter.size;
  }
}

void downloadComic(ComicItem comic, BuildContext context, List<String> eps) async{
  if(GetPlatform.isWeb){
    showMessage(context, "Web端不支持下载".tr);
    return;
  }
  for(var i in downloadManager.downloading){
    if(i.id == comic.id){
      showMessage(context, "下载中".tr);
      return;
    }
  }
  var downloaded = <int>[];
  if(DownloadManager().downloaded.contains(comic.id)){
    var downloadedComic = await DownloadManager().getComicFromId(comic.id);
    downloaded.addAll(downloadedComic.downloadedEps);
  }
  if(UiMode.m1(Get.context!)) {
    showModalBottomSheet(context: Get.context!, builder: (context){
      return SelectDownloadChapter(eps.sublist(1), (selectedEps){
        downloadManager.addPicDownload(comic, selectedEps);
        showMessage(context, "已加入下载".tr);
      }, downloaded);
    });
  }else{
    showSideBar(
        Get.context!,
      SelectDownloadChapter(eps.sublist(1), (selectedEps){
        downloadManager.addPicDownload(comic, selectedEps);
        showMessage(context, "已加入下载".tr);
      }, downloaded),
      useSurfaceTintColor: true
    );
  }
}