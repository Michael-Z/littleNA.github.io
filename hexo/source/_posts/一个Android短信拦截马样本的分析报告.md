---
title: 一个Android短信拦截马样本的分析报告
date: 2018-09-27 16:15:28
tags:
  - 木马
  - Android
  - 短信拦截
categories: 样本分析
---
> &emsp;&emsp;近期有个朋友发来了一个针对俄罗斯的android恶意样本，该恶意apk伪装成一个照片应用，诱导用户点击下载并安装。本文对该恶意apk进行详细的分析。（说实话，这个木马跟我15年分析的第一个短信拦截马的功能差不多，发出来原因有3点：1)样本新且服务器还存活，本报告解密了远控端指令下发的相关流量。2)报告最后尝试利用威胁情报来分析这个黑客组织。3)为后续的文章做铺垫。）

# 木马简介

&emsp;&emsp;木马是典型的android短信拦木马，为了逃逸杀毒引擎的静态扫描，该apk集成了一个内存泄露检测工具LeakCanary来增加良性行为，这个工具在github开源，被广大android开发者所使用，项目的star数达到了2w+。


# 基本信息

- 名称：Фoто
- 包名：com.tie.roar
- 入口：com.tie.roar.ConventionCommitment
- 版本信息：Ver：2.102.245(1) SDK：16 TargetSDK：25
- MD5: f47d664bba5d751ad4390d75f4f19b0f
- SHA-1: ec1b835728eb538e272c9c6f8f7c02dcb41c53da

<!-- more -->

# 详细行为分析
##  清单信息

&emsp;&emsp;从下图可以看到，木马由多个组件组成，各组件负责不同功能，应用权限也声明了几个比较敏感的短信相关的权限。

|||
| :: | :: |
| {% asset_img 1.png %} | {% asset_img 2.png %} |

## 隐藏自身

&emsp;&emsp;木马安装运行后，会隐藏自身的图标，降低自身被发现的概率，达到常驻系统的目的。

{% asset_img 3.png %}

&emsp;&emsp;下图是变化过程：

{% asset_img 4.png %}

## 字符串解密

{% asset_img 5.png %}

&emsp;&emsp;通过手动分析，发现木马对关键的字符串进行了加密，分析算法，得知是使用了自定义的异或算法加上base64编码：

{% asset_img 6.png %}

&emsp;&emsp;解密后的字符串：

```java
a=”android.settings.ACCESSIBILITY_SETTINGS”
b=”Для уcтрaннения проблемы Вам нeобходимo включить 'Системноe прилoжениe'
   1.Для этогo перейдите нa страницу нaстрoек
   2.Выбeрите из cпискa 'Системноe прилoжениe'
   3.Включитe егo.”
c=”Систeмнaя непoладка”
d=”Системноe прилoжениe”
g=”http://whyadvhot.com/eqv2pvqgumbobw8n/index.php”
h=”command”
i=”model”
j=”timestamp”
k=”ver”
l=”waitrun”
m=”android.provider.Telephony.SMS_RECEIVED”
```

&emsp;&emsp;变量b是一段俄语，通过google翻译可以知道该段文字是用来诱惑用户给木马打开辅助系统的权限，木马利用辅助系统可以做很多事情，比如模拟物理按键、模拟点击（自动安装应用）、息屏、亮屏幕等操作。

{% asset_img 7.png %}

&emsp;&emsp;变量g是木马上线访问的url，通过这个url可以关联分析出这个黑客或者组织在过去10年的一些活动，后面进行分析。

## 木马上线

&emsp;&emsp;木马使用Http进行上线通知，并使用Http协议传输命令进行操控客户端。

{% asset_img 8.png %}

&emsp;&emsp;截获的数据包：

{% asset_img 9.png %}

&emsp;&emsp;解密后：

```json
{"type":1,"data":{"model":"Android SDK built for x86","ver":"6.3.4","android":"4.1.2",
"cell":"Android","x":260},"id":"d3b71c99311712cb"}
```

## 指令下达

&emsp;&emsp;木马通过回传指令让受控端进行一些敏感的操作，比如拨打电话、定向发送短信、劫持短信内容等。指令如下图所示：

{% asset_img 10.png %}

&emsp;&emsp;分析表明，7号指令是拨打电话、19号指令是劫持短信并且替换字符、11号指令是定向发送短信。这样的话，木马就能够通过后台扣费、获取银行验证码等手段来获利。部分解密流量如下：

```json
{"command":0,"params":{"timestamp":1537173808},"waitrun":0},
{"command":"11","params":{"to":"+79173065404","body":"test number 2412403","timestamp":12281930,"x":0},"waitrun":1000}
```

## 收集用户信息

&emsp;&emsp;读取短信、联系人等信息。

{% asset_img 11.png %}

## 监控短信

&emsp;&emsp;木马会一直监控用户短信情况，当用户收到的短信时立马将短信内容通过url发送到服务器。下面是组包的代码：

{% asset_img 12.png %}

&emsp;&emsp;用模拟器测试一下收到短信的情况：

{% asset_img 13.png %}

&emsp;&emsp;短信发送后截获的木马上传数据到服务器的http包：

{% asset_img 14.png %}

&emsp;&emsp;解密数据如下：

```json
{"type":2,"data":{"n":"6505551212","t":"Hello, this is my password: 888888."},"id":"d3b71c99311712cb"}
```

## 保活自身

&emsp;&emsp;木马启动服务并使用onServiceConnected()函数来判断app是否在线。

{% asset_img 15.png %}

&emsp;&emsp;当运行的服务发现app进程被杀掉的时候，马上启动app，并在前台伪装系统应用显示。

{% asset_img 16.png %}

## 前台伪装

&emsp;&emsp;木马伪装成系统应用在前台显示，避免后台运行被系统清理。

{% asset_img 17.png %}

&emsp;&emsp;下面是显示的图片：

{% asset_img 18.png %}

## 激活辅助功能

&emsp;&emsp;当发现用户打开对木马不利的应用时，木马一直弹窗，逼迫用户跳转到开启辅助功能的界面。这样导致用户没法手动结束掉木马进程。

{% asset_img 19.png %}

{% asset_img 20.png %}

## 木马保护

&emsp;&emsp;如果木马获得辅助功能，木马会通过模拟点击物理按键返回来阻止用户打开某些程序，这个程序黑名单由40号指令获取。阻止打开程序的相关代码：

{% asset_img 21.png %}

&emsp;&emsp;解密后的40号指令数据包如下：

```json
{"command":40,"params":{"text":"clean,.kms.,.drweb,.eset.,.ikarus.,.settings,:interactor,.gms.persistent,.packageinstaller,.cmcm,ahnlab,virus,avira,security,dianxinos,wsandroid,trendmicro,malware,tencent,sophos,mcafee,fsecure,sber,sber,com.android.mms",
"t":"android:id\/right_button,android:id\/button1,android:id\/restricted_action,android:id\/action_button,com.android.settings:id\/restricted_action,com.android.settings:id\/action_button,да,ок,подтвердить,разрешить,отправить,активировать","timestamp":1537173681,"x":1},"waitrun":0}
```

&emsp;&emsp;从数据包中可以看到mcafee、kms 、security、clean等一些安全厂商的包名字段，还有系统设置settings的字段。如果用户打开的应用名包含这些字段，木马将模拟物理返回按钮，导致用户打不开这些程序，也就无法手动杀掉木马进程了。

# 威胁情报分析

&emsp;&emsp;木马访问的whyadvhot.com域名指向了IP为185.234.218.60的服务器，该IP在微步在线中被标记为恶意服务器，部分信息的信息如下：

{% asset_img 22.png %}

&emsp;&emsp;该IP地址在上半年的2018年3月份还发起了一起恶意邮箱攻击的事件。通过使用关联分析，可以发现该木马的作者是具有丰富的黑产经验，从下图可以看出，在服务器上面还存有大量的apk变种木马。

{% asset_img 23.png %}

&emsp;&emsp;从数据中还可以查到，该黑客组织最早的活动可以追溯到2009年，一直进行着windows平台的木马传播，捕获的PE样本时间从2014年至2018年之间，说明该黑客组织一直保持着活跃，并从2018年9月开始传播大量的apk木马。从这次捕获到的木马也可以看出，该木马的功能比较局限，实现的手法也相对粗糙，在笔者分析的这段时间里，木马服务器还经常掉线，可能该木马还处于测试阶段，当然，对该组织的后续活动，我们也会一直跟踪下去。

# 总结

&emsp;&emsp;这类木马主要是为了控制用户手机，通过拨打制定电话、发送指定短信，来到达恶意扣费的目的，进而谋取利益。当然，该木马还可以会监控用户短信，当用户正在进行短信验证，验证码将会发送到黑客服务器，进入导致用户账户或者银行财产等被盗。因此，在此建议用户一定不要随意点开的链接并按照应用。最好的方式是在设置中选择不允许从未知来源安装软件，从官方途径安装应用，这样就能避免被此类木马感染。
