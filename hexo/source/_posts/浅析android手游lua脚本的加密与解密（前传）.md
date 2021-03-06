---
title: 浅析android手游lua脚本的加密与解密（前传）
date: 2018-07-07 18:37:04
tags: 
  - lua
  - luajit
  - 手游安全
categories: lua加解密
---
# 前言

&emsp;&emsp;为了能让一些同学更好的学习lua的逆向，我把收集的一些资料组合成一篇lua加解密的相关工作给大家参考，当然，看这篇文章之前还是需要一些lua的基础知识，这里推荐云风大佬的《Lua源码欣赏》[[19]](#19)，建议结合搜索引擎学习之。

&emsp;&emsp;文章分2部分介绍，第1部分介绍lua加解密的相关文章介绍，第2部分介绍lua的相关工具。

<!-- more -->

# 相关工作：
&emsp;&emsp;这一节介绍了互联网上对lua的各种相关文章，包括lua的加解密如文件格式的解析、基于lua的游戏和比赛的介绍、lua的hook技术等。

**1. lua加解密入门：**

&emsp;&emsp;非虫大佬[[1-4]](#1-4) 写了4篇关于luac和luajit文件格式和字节码的相关文章，并开源了010Editor的解析luac和luajit的模板代码。Ganlv 同学[[7]](#7) 在吾爱破解写了7篇关于lua加解密的系列教程。
腾讯gslab[[9]](#9) 写了一篇关于lua游戏逆向的入门介绍，这是一篇比较早的lua游戏解密的文章。INightElf 同学[[10]](#10) 写了一篇关于lua脚本反编译入门的文章。

**2. 基于lua的手游：**

&emsp;&emsp;lua不仅能用于端游戏，也能用于手游，而且由于手游的火热，带动了lua逆向相关分析文章的分享。wmsuper 同学[[11]](#11) 在android平台下解密了腾讯游戏开心消消乐的lua脚本，后续可以通过修改lua脚本达到作弊的目的。Unity 同学[[8]](#8) 通过hook的方法解密和修改lua手游《放置江湖》的流程，达到修改游戏奖励的目的。littleNA 同学[[12]](#12) 通过3种方式解密了3个手游的lua脚本，并且修复了梦幻手游lua opcode的顺序。

**3. 基于lua的比赛：**

&emsp;&emsp;随着国内CTF的发展，lua技术也运用到了比赛中。看雪ctf2016第2题[[13]](#13)、2017第15题[[14]](#14)和腾讯游戏安全2018决赛第2题[[15]](#15)都使用了lua引擎作为载体的CrackMe比赛，其中看雪2016将算法验证用lua代码实现并编译成luac，最后还修改了luac的文件头，使得反编译工具报错；看雪2017的题使用壳和大量的混淆，最后一步是luajit的简单异或运算；腾讯2018使用的lua技术更加深入，进阶版更是修改了lua的opcode顺序，并使用lua编写了一个虚拟机。以上3题的writeup网上都可以搜索到，有兴趣的朋友可以练练手，加深印象。

**4. lua hooking：**

&emsp;&emsp;Hook是修改软件流程的常用手段，lua中也存在hook技术。曾半仙 同学[[9]](#9) 在看雪发布了一种通过hook lua字节码达到修改游戏逻辑的方法，并发布了一个lua汇编引擎。Nikc Cano[[5]](#5) 的blog写了一篇关于Hooking luajit的文章，興趣使然的小胃 同学[[6]](#6) 对该篇文章进行了翻译。

# 工具介绍：
&emsp;&emsp;逆向解密lua和luajit游戏都有相关的工具，这一节将对一些主流的工具进行介绍。

**1. lua相关：**
- luadec [[16]](#16)：这是一个用c语言结合lua引擎源码写的开源lua反编译器，解析整个lua字节码文件并尽可能的还原为源码。当然，由于还原的是高级语言，所以兼容性一般，当反编译大量文件时肯定会遇到bug，这时就需要自己手动修复bug；并且很容易被针对造成反编译失败。目前支持的版本有lua5.1，5.2和5.3。

- chunkspy：一款非常有用的lua分析工具，本身就是lua语言所写。它解析了整个lua字节文件，由于其输出的是lua的汇编形式，所以兼容性非常高，也造成了一定的阅读障碍。chunkspy 不仅可以解析luac文件，它还包括了一个交互式的命令，可以将输入的lua脚本转换成lua字节码汇编的形式，这对学习lua字节码非常有帮助。luadec工具中集成了这个脚本，目前支持的版本也是有lua5.1，5.2和5.3。

- unluac：这也是一个开源的lua反编译器，java语言所写，相比luadec 工具兼容性更低,。一般很少使用，只支持lua5.1，当上面工具都失效时可以尝试。

**2. luajit相关：**
- luajit-decomp[[17]](#17)：github开源的一款luajit反编译工具，使用au3语言编写。先通过luajit原生的exe文件将luajit字节码文件转换成汇编，然后该工具再将luajit汇编转换成lua语言。由于反汇编后的luajit字节码缺少很多信息，如变量名、函数名等，造成反编译后的结果读起来比较隐晦，类似于ida的F5。但是兼容性超好，只要能够反汇编就能够反编译，所以使用时需要替换对应版本的luajit引擎（满足反汇编的需求）。目前是支持所有的luajit版本。

- ljd[[18]](#18)：也是github开源的一款luajit反编译工具，使用python编写，与luajit-decomp 反编译luajit汇编的方式不同，其从头解析了整个luajit文件，能够获取更多的信息，还原的程度更高，但是由于精度更高，所以兼容性也会弱一点。查看该项目的fork可以获取更多的其他兼容版本，目前支持的版本有luajit2.0、luajit2.1等。

# 参考文章
<div id="1-4"></div>
* [1] 飞虫 《Lua程序逆向之Luac文件格式分析》 https://www.anquanke.com/post/id/87006
* [2] 飞虫 《Lua程序逆向之Luac字节码与反汇编》 https://www.anquanke.com/post/id/87262
* [3] 飞虫 《Lua程序逆向之Luajit文件格式》 https://www.anquanke.com/post/id/87281
* [4] 飞虫 《Lua程序逆向之Luajit字节码与反汇编》 https://www.anquanke.com/post/id/90241
<div id="5"></div>
* [5] Nick Cano 《Hooking LuaJIT》 https://nickcano.com/hooking-luajit
<div id="6"></div>
* [6] 興趣使然的小胃 《看我如何通过hook攻击LuaJIT》 https://www.anquanke.com/post/id/86958
<div id="7"></div>
* [7] Ganlv 《lua脚本解密1：loadstring》 https://www.52pojie.cn/thread-694364-1-1.html 
<div id="8"></div>
* [8] unity 《【放置江湖】LUA手游 基于HOOK 解密修改流程》 https://www.52pojie.cn/thread-682778-1-1.html
<div id="9"></div>
* [9] 游戏安全实验室 《Lua游戏逆向及破解方法介绍》 http://gslab.qq.com/portal.php?mod=view&aid=173
<div id="10"></div>
* [10] INightElf 《[原创]Lua脚本反编译入门之一》 https://bbs.pediy.com/thread-186530.htm
<div id="11"></div>
* [11] wmsuper 《开心消消乐lua脚本解密》 https://www.52pojie.cn/thread-611248-1-1.html
<div id="12"></div>
* [12] littleNA 《浅析android手游lua脚本的加密与解密》 https://bbs.pediy.com/thread-216969.htm
<div id="13"></div>
* [13] 《看雪 2016CrackMe 第二题》 https://ctf.pediy.com/game-fight-3.htm
<div id="14"></div>
* [14] 《看雪 2017CrackMe 第十五题》 https://ctf.pediy.com/game-fight-45.htm
<div id="15"></div>
* [15] 《腾讯游戏安全技术竞赛》 https://www.52pojie.cn/forum-77-1.html
<div id="16"></div>
* [16] luadec https://github.com/viruscamp/luadec
<div id="17"></div>
* [17] ljd https://github.com/NightNord/ljd
<div id="18"></div>
* [18] luajit-decomp https://github.com/bobsayshilol/luajit-decomp
<div id="19"></div>
* [19] 云风 《Lua源码欣赏》 https://storage.googleapis.com/google-code-archive-downloads/v2/code.google.com/luadec/云风-lua源码欣赏-lua-5.2.pdf



