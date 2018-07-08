---
title: 浅析android手游lua脚本的加密与解密（后续）
date: 2018-07-08 22:15:44
tags: 
  - lua
  - luajit
  - 手游安全
categories: lua加解密
---

# 前言
&emsp;&emsp;趁着周末，把lua的后续文章也写完了。

# 反编译对抗

&emsp;&emsp;众所周知，**反汇编/反编译** 工具在逆向人员工作中第一步被使用，其地位非常之高，而对于软件保护者来说，如何对抗 反汇编/反编译 就显得尤为重要。例如，动态调试中对OD的的检测、内核调试对windbg的破坏、加壳加花对IDA静态分析的阻碍、apktool的bug导致对修改后的apk反编译失败、修改PE头导致OD无法识别、修改 .Net dll中的区段导致ILspy工具失效等等例子，都说明对抗反编译工具是很常用的一种软件保护手段，当然lua的反编译工具也面临这个问题。处理这样的问题无非就几种思路：

1. 用调试器调试反编译工具为何解析错误，排查原因。
2. 用调试器调试原引擎是如何解析文件的。
3. 用文件格式解析工具解析文件，看哪个点解析出错。

&emsp;&emsp;下面将以3个例子来实战lua反编译是如何被对抗的。

<!-- more -->

# 例子1：一个简单的问题

&emsp;&emsp;这是在看雪论坛看到的一个问题，问题是由于游戏（可能是征途手游）将lua字符串的长度int32修改为int64，导致反编译失败的一个例子，修复方法请看帖子中本人的回答，地址：https://bbs.pediy.com/thread-217033.htm 

# 例子2：2018 腾讯游戏安全

&emsp;&emsp;这一节主要是讲一下如何修复当lua的opcode被修改的情况，以及如何修复该题对抗lua反编译的问题。

## opcode问题及其修复
&emsp;&emsp;修复opcode的目的是 当输入题目的luac文件，反汇编工具Chunkspy和反编译工具luadec能够输出正确的结果。

&emsp;&emsp;首先，我们在ida中分析lua引擎tmgs.dll文件，然后定位到luaV_execute函数（搜索字符串“ 'for' limit must be a number ”），发现switch下的case的参数（lua的opcode）是乱序的，到这里我们就能够确认，该题的lua虚拟机opcode被修改了。

&emsp;&emsp;接着，我们进行修复操作。一种很耗时的办法就是一个一个opcode还原，分析每一个case下面的代码然后找出对应opcode的顺序。但是这一题我们不用这么麻烦，通过对比分析我们发现普通版的题目并没有修改opcode：

| 普通版lua引擎的luaV_execute函数 | 进阶版lua引擎的luaV_execute函数 |
| :-: | :-: |
| {% asset_img 1.png %} | {% asset_img 2.png %} |

&emsp;&emsp;观察发现，进阶版的题目只是修改了每个case的数值或者多个值映射到同一个opcode，但是没有打乱case里的代码（也就是说，虚拟机解析opcode代码的顺序没有变，只是修改了对应的数值，这跟梦幻手游的打乱opcode的方法不同）。由于lua5.3只使用到0x2D的opcode，而一个opcode长度为6位（0x3F），该题就将剩余的没有使用的字节映射到同一个opcode下，修复时只需要反过来操作就可以了。分析到这里，我们的修复方案就出来了：

1. 通过ida分别导出2个版本的 luaV_execute 的文本
2. 通过python脚本提取opcode的修复表
3. 在工具（Chunkspy和luadec）初始化lua文件后，用修复表将opcode替换
4. 测试运行，修复其他bug

&emsp;&emsp;第一步直接IDA手动导出: File --> Produce file --> Create LST File ；第二步使用python分析，代码如下：

```python
# -*- coding: utf-8 -*-

# 通过扫码IDA导出的文本文件，获取lua字节码的opcode顺序
def get_opcode(filepath):
    f = open(filepath)
    lines = f.readlines()
    opcodes = []

    # 循环扫码文件的每一行
    for i in range(len(lines)):
        line = lines[i]
        if line.find('case') != -1:
            line = line.replace('case', '')
            line = line.replace(' ', '')
            line = line.replace('\n','')
            line = line.replace('u:', '')

            # 如果上一行也是case，那么这2个case对应同一个opcode
            if lines[i-1].find('case') != -1:
                opcode = opcodes[-1]
                opcode.append(line)
            else:
                opcode = []
                opcode.append(line)
                opcodes.append(opcode)
    f.close()
    return opcodes

o1 = get_opcode(u'基础版opcode.txt')
o2 = get_opcode(u'进阶版opcode.txt')

# 还原
for i in range(len(o1)):
    print '基础版：',o1[i],'\t进阶版：',o2[i]

# 映射opcode获取修复表
op_tbl = [-1 for i in range(64)]
for i in range(len(o1)):
    o1opcode = o1[i][0]
    o1opcode = o1opcode.replace('0x','')

    for o2opcode in o2[i]:
        o2opcode = o2opcode.replace('0x','')
        op_tbl[int(o2opcode,16)] = int(o1opcode,16)

print '修复表：',op_tbl
```

&emsp;&emsp;运行结果：
```python
基础版： ['0']        进阶版： ['6', '7', '0x16', '0x1B']
基础版： ['1']        进阶版： ['0x22', '0x28', '0x29', '0x3C']
基础版： ['2']        进阶版： ['0x3E']
基础版： ['3']        进阶版： ['0x3B']
基础版： ['4']        进阶版： ['0x12']
基础版： ['5']        进阶版： ['8', '0x11', '0x17', '0x36']
基础版： ['6']        进阶版： ['2']
基础版： ['7']        进阶版： ['0xD']
基础版： ['8']        进阶版： ['0x1A']
基础版： ['9']        进阶版： ['1']
基础版： ['0xA']      进阶版： ['0x1D']
基础版： ['0xB']      进阶版： ['0x1F']
基础版： ['0xC']      进阶版： ['0xE']
基础版： ['0xD']      进阶版： ['0x31']
基础版： ['0xE']      进阶版： ['0x2F']
基础版： ['0xF']      进阶版： ['0x1E']
基础版： ['0x12']     进阶版： ['0x13']
基础版： ['0x14']     进阶版： ['0x2B']
基础版： ['0x15']     进阶版： ['0x1C']
基础版： ['0x16']     进阶版： ['0x2D']
基础版： ['0x17']     进阶版： ['0x19']
基础版： ['0x18']     进阶版： ['0x3F']
基础版： ['0x10']     进阶版： ['0x15']
基础版： ['0x13']     进阶版： ['0x24']
基础版： ['0x11']     进阶版： ['0x3A']
基础版： ['0x19']     进阶版： ['0x18']
基础版： ['0x1A']     进阶版： ['0x33']
基础版： ['0x1B']     进阶版： ['0xF']
基础版： ['0x1C']     进阶版： ['0x34']
基础版： ['0x1D']     进阶版： ['0x20']
基础版： ['0x1E']     进阶版： ['5', '9', '0xA', '0x25']
基础版： ['0x1F']     进阶版： ['0x30']
基础版： ['0x20']     进阶版： ['0x26']
基础版： ['0x21']     进阶版： ['0x35']
基础版： ['0x22']     进阶版： ['0x38']
基础版： ['0x23']     进阶版： ['0x2A']
基础版： ['0x24']     进阶版： ['0x23', '0x37', '0x39', '0x3D']
基础版： ['0x25']     进阶版： ['0x27']
基础版： ['0x27']     进阶版： ['0x2C']
基础版： ['0x28']     进阶版： ['0x32']
基础版： ['0x29']     进阶版： ['0x21']
基础版： ['0x2A']     进阶版： ['3']
基础版： ['0x2B']     进阶版： ['0xC']
基础版： ['0x2C']     进阶版： ['0x2E']
基础版： ['0x2D']     进阶版： ['0x14']
基础版： ['0x26']     进阶版： ['4']
修复表： [-1, 9, 6, 42, 38, 30, 0, 0, 5, 30, 30, -1, 43, 7, 12, 27, -1, 5, 4, 18, 45, 16, 0, 5, 25, 23, 8, 0, 21, 10, 15, 11, 29, 41, 1, 36, 19, 30, 32, 37, 1, 1, 35, 20, 39, 22, 44, 14, 31, 13, 40, 26, 28, 33, 5, 36, 34, 36, 17, 3, 1, 36, 2, 24]
```

&emsp;&emsp;注意了，这里有几个opcode是没有对应关系的（默认是-1），跟踪代码发现，其实这些opcode的功能相当于nop操作，而原本lua是不存在nop的，我们只需在修复的过程中跳过这个字节码即可。

&emsp;&emsp;最后将获取的修复表替换到工具中，Chunspy修复点在DecodeInst函数中，修改结果如下：
```lua
function DecodeInst(code, iValues)
  local iSeq, iMask = config.iABC, config.mABC
  local cValue, cBits, cPos = 0, 0, 1
  -- decode an instruction
  for i = 1, #iSeq do
    -- if need more bits, suck in a byte at a time
    while cBits < iSeq[i] do
      cValue = string.byte(code, cPos) * (1 << cBits) + cValue
      cPos = cPos + 1; cBits = cBits + 8
    end
    -- extract and set an instruction field
    iValues[config.nABC[i]] = cValue % iMask[i]
    cValue = cValue // iMask[i]
    cBits = cBits - iSeq[i]
  end

  -- add by littleNA
  local optbl = { -1, 9, 6, 42, 38, 30, 0, 0, 5, 30, 30, -1, 43, 7, 12, 27, -1, 5, 4, 18, 45, 16, 0, 5, 25, 23, 8, 0, 21, 10, 15, 11, 29, 41, 1, 36, 19, 30, 32, 37, 1, 1, 35, 20, 39, 22, 44, 14, 31, 13, 40, 26, 28, 33, 5, 36, 34, 36, 17, 3, 1, 36, 2, 24 }    
  iValues.OP = optbl[iValues.OP+1]  -- 注意，lua的下标是从1开始的数起的
  -- add by littleNA end

  iValues.opname = config.opnames[iValues.OP]   -- get mnemonic
  iValues.opmode = config.opmode[iValues.OP]
 
 -- add by littleNA
  if iValues.OP == -1 then
    iValues.opname = "Nop"
    iValues.opmode = iABx
  end
  -- add by littleNA end
 
 if iValues.opmode == iABx then                 -- set Bx or sBx
    iValues.Bx = iValues.B * iMask[3] + iValues.C
  elseif iValues.opmode == iAsBx then
    iValues.sBx = iValues.B * iMask[3] + iValues.C - config.MAXARG_sBx
  elseif iValues.opmode == iAx then
    iValues.Ax = iValues.B * iMask[3] * iMask[2] + iValues.C * iMask[2] + iValues.A
  end
  return iValues
end
```

&emsp;&emsp;测试发现出错了，出错结果：
{% asset_img 3.png %}

&emsp;&emsp;从出错的结果可以看出是luac文件的版本号有错误，这里无法识别lua 11的版本其实是题目故意设计让工具识别错误，我们将文件的第4个字节（lua版本号）11修改成53就可以了。正确结果：
{% asset_img 4.png %}

&emsp;&emsp;luadec修复点在ldo.c文件的f_parser函数，并且增加一个RepairOpcode函数，修复如下：
```c++
// add by littleNA
void RepairOpcode(Proto* f)
{
    // opcode 替换表
    char optbl[] = { -1, 9, 6, 42, 38, 30, 0, 0, 5, 30, 30, -1, 43, 7, 12, 27, -1, 5, 4, 18, 45, 16, 0, 5, 25, 23, 8, 0, 21, 10, 15, 11, 29, 41, 1, 36, 19, 30, 32, 37, 1, 1, 35, 20, 39, 22, 44, 14, 31, 13, 40, 26, 28, 33, 5, 36, 34, 36, 17, 3, 1, 36, 2, 24 };
    for (int i = 0; i < f->sizecode; i++)
    {
        Instruction code = f->code[i];
        OpCode o = GET_OPCODE(code);
        SET_OPCODE(code, optbl[o]);

        f->code[i] = code;
    }

    for (int i = 0; i < f->sizep; i++)
    {// 处理子函数
        RepairOpcode(f->p[i]);
    }
}
// add by littleNA end

static void f_parser (lua_State *L, void *ud) {
  LClosure *cl;
  struct SParser *p = cast(struct SParser *, ud);
  int c = zgetc(p->z);  /* read first character */
  if (c == LUA_SIGNATURE[0]) {
    checkmode(L, p->mode, "binary");
    cl = luaU_undump(L, p->z, p->name);
    
    // add by littleNA
    Proto *f = cl->p;
    RepairOpcode(f);
    // add by littleNA end
  }
  else {
    checkmode(L, p->mode, "text");
    cl = luaY_parser(L, p->z, &p->buff, &p->dyd, p->name, c);
  }
  lua_assert(cl->nupvalues == cl->p->sizeupvalues);
  luaF_initupvals(L, cl);
}
```

&emsp;&emsp;运行一下，发现出错了，并且停留在StringBuffer_add函数中，其中str指向错误的地方，导致字符串读取出错：
{% asset_img 5.png %}

&emsp;&emsp;到这里我们修复了opcode，并且Chunkspy顺利反汇编，但是luadec的反编译还是有问题，我们在下一节分析。

## 反编译问题及其修复
&emsp;&emsp;看了几个大佬的writeup，发现他们都没有修复这个问题，解题过程中都是直接分析的是lua汇编代码。我们看看出错的原因，查看vs的调用堆栈：

{% asset_img 6.png %}

&emsp;&emsp;发现上一层函数是listUpvalues函数，也就是说luadec在解析upvalues时出错了，深入分析发现其实是由于文件中的upvalue变量名被抹掉了，导致解析出错，我们只需要在ProcessCode函数（decompile.c文件）调用listUpvalues函数前，增加临时的upvalue命名就可以了，修改代码如下：

```c++
char* ProcessCode(Proto* f, int indent, int func_checking, char* funcnumstr) 
{
...
       // make function comment
       StringBuffer_printf(str, "-- function num : %s", funcnumstr);
       if (NUPS(f) > 0) {
              // add by littleNA
              for (i = 0; i<f->sizeupvalues; i++) {
                     char tmp[10];
                     sprintf(tmp, "up_%d", i);
                     f->upvalues[i].name = luaS_new(f->L, tmp);
              }
              // add by littleNA end
              StringBuffer_add(str, " , upvalues : ");
              listUpvalues(f, str);
       }
...
}
```
&emsp;&emsp;最后完美运行luadec，反编译成功。

# 例子3：梦幻西游手游
&emsp;&emsp;这个例子内容较多，并且这篇文章也够长了，索性就把这节单独写成一篇[文章](https://litna.top/2018/07/08/梦幻手游部分Luac反编译失败的解决方法/)。