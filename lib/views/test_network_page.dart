import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pica_comic/views/auth_page.dart';
import 'package:pica_comic/views/main_page.dart';
import 'package:pica_comic/views/settings/settings_page.dart';
import '../base.dart';
import 'package:pica_comic/network/jm_network/jm_main_network.dart';
import 'package:pica_comic/network/picacg_network/methods.dart';

class TestNetworkPage extends StatefulWidget {
  const TestNetworkPage({Key? key}) : super(key: key);

  @override
  State<TestNetworkPage> createState() => _TestNetworkPageState();
}

class _TestNetworkPageState extends State<TestNetworkPage> {
  bool isLoading = true;
  String? message;
  String status = "正在获取用户信息".tr;

  @override
  void initState() {
    login();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Material(
        child: Stack(
          children: [
            if(isLoading)
              Positioned(
                top: MediaQuery.of(context).size.height/2-100,
                left: 0,
                right: 0,
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: CircularProgressIndicator(),
                ),
              ),
            if(!isLoading)
              Positioned(
                top: MediaQuery.of(context).size.height/2-150,
                left: 0,
                right: 0,
                child: const Align(
                  alignment: Alignment.topCenter,
                  child: Icon(Icons.error_outline,size:60,),
                ),
              ),
            if(isLoading)
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).size.height/2-40,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(status),
                ),
              ),
            if(isLoading)
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).size.height/2-10,
                child: SizedBox(
                  width: 80,
                  height: 40,
                  child: Center(
                    child: FilledButton(
                      child: const Text("跳过"),
                      onPressed: ()=>Get.offAll(const MainPage()),
                    ),
                  ),
                ),
              ),
            if(!isLoading)
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).size.height/2-80,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(message??"网络错误".tr, textAlign: TextAlign.center,),
                ),
              ),

            if(!isLoading)
              Positioned(
                top: MediaQuery.of(context).size.height/2-30,
                left: 0,
                right: 0,
                child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 180,
                      height: 50,
                      child: Row(
                        children: [
                          FilledButton.tonal(
                            onPressed: (){
                              setState(() {
                                isLoading = true;
                                login();
                              });
                            },
                            child: Text("重试".tr),
                          ),
                          const Spacer(),
                          FilledButton.tonal(
                            onPressed: () => goToMainPage(),
                            child: Text("跳过".tr),
                          )
                        ],
                      ),
                    )
                ),
              ),
            if(!isLoading&&!GetPlatform.isWeb)
              Positioned(
                bottom: 20,
                left: MediaQuery.of(context).size.width/2-200,
                child: SizedBox(
                  width: 400,
                  child: ListTile(
                    leading: const Icon(Icons.settings),
                    title: Text("转到设置".tr),
                    trailing: const Icon(Icons.arrow_right),
                    onTap: ()=>Get.to(()=>const SettingsPage()),
                  ),
                ),
              )
          ],
        ),
      )
    );
  }

  void goToMainPage(){
    if(appdata.settings[13]=="1"){
      Get.offAll(()=>const AuthPage());
    }else{
      Get.offAll(()=>const MainPage());
    }
  }

  ///获取哔咔账号信息, 登录禁漫账号
  Future<void> login() async{
    //如果同时进行两个网络请求, jm的登录存在问题, 导致无法获取收藏, 并不清楚为什么
    message = null;
    jmNetwork.updateApi();
    if(appdata.token != "") {
      try {
        var res = await network.getProfile();
        if (res == null) {
          message = network.status ? network.message : "网络错误".tr;
          message = "登录哔咔时发生错误\n".tr + message.toString();
        } else {
          appdata.user = res;
          await appdata.writeData();
        }
      }
      catch(e){
        message = "登录哔咔时发生错误\n".tr + e.toString();
      }
    }
    try {
      setState(() {
        status = "正在登录禁漫";
      });
    }
    catch(e){
      //忽视
    }
    var res2 = await jmNetwork.loginFromAppdata();
    if(res2.error){
      message = res2.errorMessage;
      message = "登录禁漫时发生错误\n".tr + message.toString();
    }
    if(message == null){
      goToMainPage();
    }else{
      try {
        setState(() {
          isLoading = false;
        });
      }
      catch(e){
        //已退出页面
      }
    }
  }
}
