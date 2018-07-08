---
title: 梦幻手游部分Luac反编译失败的解决方法
date: 2018-07-08 23:01:33
tags: 
  - lua
  - luac反编译
  - 手游安全
  - 梦幻西游手游
categories: lua加解密
---

# 前言
&emsp;&emsp;这一篇是去年学习破解梦幻西游手游lua代码时记录的一些问题，今天将其整理并共享出来，所以不一定适合现在版本的梦幻手游，大家还是以参考为目的呗。lua相关的文章（共4篇）到此也写完了，如果以后还有新的东西会继续更新，接下来会写几篇关于2018 腾讯游戏安全竞赛的详细分析，敬请期待。

# 十二处bug修复
&emsp;&emsp;当时反编译梦幻西游手游时遇到的问题大约有12个，修改完基本上可以完美复现lua源码，这里用的luadec5.1版本。

## 修复一

&emsp;&emsp;**问题1：** 由于梦幻手游lua的opcode是被修改过的，之前的解决方案是找到梦幻的opcode，替换掉反编译工具的原opcode，并且修改opmode，再进行反编译。问题是部分测试的结果是可以的，但是当对整个手游的luac字节码反编译时，会出现各种错误，原因是luadec5.1 在很多地方都默认了opcode的顺序，并进行了特殊处理，所以需要找到这些特殊处理的地方一一修改。不过这样很麻烦，从而想到另外一种方式，不修改原来的opcode和opmode，而是在luadec解析到字节码的时候，将opcode还原成原来的opcode。

&emsp;&emsp;**解决1：** 定位到解析code的位置在  lundump.c --> LoadFunction --> LoadCode （位置不唯一，可以看上一篇腾讯比赛的修复），当执行完LoadCode函数的时候，f变量则指向了code的结构，在这之后执行自己写的函数ConvertCode函数，如下：

```c++
// add by littleNA
void ConvertCode(Proto *f)
{
        int pnOpTbl[] = { 3,13,18,36,27,10,20,25,34,2,32,15,30,16,31,9,26,24,29,1,6,28,4,17,33,0,7,11,5,14,8,19,35,12,21,22,23,37 };
        for (int pc = 0; pc < f->sizecode; pc++)
        {
               Instruction i = f->code[pc];
               OpCode o = GET_OPCODE(i);
               SET_OPCODE(i, pnOpTbl[o]);
               f->code[pc] = i;
        }
}
```

<!-- more -->

## 修复二

&emsp;&emsp;**问题2：** 在文件头部 反编译出现错误  -- DECOMPILER ERROR: Overwrote pending register.

&emsp;&emsp;**解决2：** 分析发现，原来是解析OP_VARARG错误导致的。OP_VARARG主要的作用是复制B-1个参数到A寄存器中，而反编译工具复制了B个参数，多了一个。修改后的代码如下：
```c++
...
         case OP_VARARG: // Lua5.1 specific.
         {
            int i;
            /*
             * Read ... into register.
             */
            if (b==0) {
                TRY(Assign(F, REGISTER(a), "...", a, 0, 1));
            } else {
                 // add by littleNA
                 // for(i = 0;i<b;i++) {
                 for(i = 0; i < b-1; i++) {
                      TRY(Assign(F, REGISTER(a+i), "...", a+i, 0, 1));
                 }
           }
           break;
         }
...
```

## 修复三

&emsp;&emsp;**问题3：** 在解析table出现反编译错误  -- DECOMPILER ERROR: Confused about usage of 。registers!

&emsp;&emsp;**解决3：** 分析发现，这里的OP_NEWTABLE 的c参数表示hash table中key的大小，而反编译代码中将c参数进行了错误转换，导致解析错误，修改代码如下：

```c++
// add by littleNA
//#define fb2int(x)    (((x) & 7) << ((x) >> 3))
#define fb2int(x)      ((((x) & 7)^8) >> (((x) >> 3)-1))
```

## 修复四

&emsp;&emsp;**问题4：** 反编译工具出错并且退出。

&emsp;&emsp;**解决4：** 跟踪发现是在AddToTable函数中，当keyed为0时会调用PrintTable，而PrintTable释放了table，下次再调用table时内存访问失败，修改代码如下：

```c++
void AddToTable(Function* F, DecTable * tbl, char *value, char *key)
{
   DecTableItem *item;
   List *type;
   int index;
   if (key == NULL) {
      type = &(tbl->numeric);
      index = tbl->topNumeric;
      tbl->topNumeric++;
   } else {
      type = &(tbl->keyed);
      tbl->used++;
      index = 0;
   }
   item = NewTableItem(value, index, key);
   AddToList(type, (ListItem *) item);
   // FIXME: should work with arrays, too
   // add by littleNA
   // if(tbl->keyedSize == tbl->used && tbl->arraySize == 0){
   if (tbl->keyedSize != 0 && tbl->keyedSize == tbl->used && tbl->arraySize == 0) {
      PrintTable(F, tbl->reg, 0);
      if (error)
         return;
   }
}
```

## 修复五

&emsp;&emsp; **问题5：** 当函数是多值返回结果并且赋值于多个变量时反编译错误，情况如下（lua反汇编）：

```lua
 21 [-]: GETGLOBAL R0 K9        ; R0 := memoryStatMap
 22 [-]: GETGLOBAL R1 K9        ; R1 := memoryStatMap
 23 [-]: GETGLOBAL R2 K2        ; R2 := preload
 24 [-]: GETTABLE  R2 R2 K3     ; R2 := R2["utils"]
 25 [-]: GETTABLE  R2 R2 K16    ; R2 := R2["getCocosStat"]
 26 [-]: CALL      R2 1 3       ; R2,R3 := R2()
 27 [-]: SETTABLE  R1 K15 R3    ; R1["cocosTextureBytes"] := R3
 28 [-]: SETTABLE  R0 K14 R2    ; R0["cocosTextureCnt"] := R2
```

&emsp;&emsp;当上面的代码解析到27行时，从寄存器去取R3时报错，原因是前面的call返回多值时，只是在F->Rcall中进行了标记，没有在寄存器中标记，编译的结果应该为：

```c++
memoryStatMap.cocosTextureCnt, memoryStatMap.cocosTextureBytes = preload.utils.getCocosStat()
```

&emsp;&emsp; **解决5：** 当reg为空时并且Rcall不为空，增加一个return more的标记，修改2个函数：

```c++
char *RegisterOrConstant(Function * F, int r)
{
   if (IS_CONSTANT(r)) {
      return DecompileConstant(F->f, r - 256); // TODO: Lua5.1 specific. Should change to MSR!!!
   } else {
      char *copy;
      char *reg = GetR(F, r);
      if (error)
         return NULL;

        // add by littleNA
        // if(){}
        if (reg == NULL && F->Rcall[r] != 0)
        {
            reg = "return more";
        }
      
      copy = malloc(strlen(reg) + 1);
      strcpy(copy, reg);
      return copy;
   }
}

```

```c++
void OutputAssignments(Function * F)
{
   int i, srcs, size;
   StringBuffer *vars;
   StringBuffer *exps;
   if (!SET_IS_EMPTY(F->tpend))
      return;
   vars = StringBuffer_new(NULL);
   exps = StringBuffer_new(NULL);
   size = SET_CTR(F->vpend);
   srcs = 0;
   for (i = 0; i < size; i++) {
      int r = F->vpend->regs[i];
      if (!(r == -1 || PENDING(r))) {
         SET_ERROR(F,"Attempted to generate an assignment, but got confused about usage of registers");
         return;
      }

      if (i > 0)
         StringBuffer_prepend(vars, ", ");
      StringBuffer_prepend(vars, F->vpend->dests[i]);

      if (F->vpend->srcs[i] && (srcs > 0 || (srcs == 0 && strcmp(F->vpend->srcs[i], "nil") != 0) || i == size-1)) {
                 // add by littleNA
                 // if()
                 if (strcmp(F->vpend->srcs[i], "return more") != 0)
                 {
                         if (srcs > 0)
                                StringBuffer_prepend(exps, ", ");
                         StringBuffer_prepend(exps, F->vpend->srcs[i]);
                         srcs++;
                }
      }

   }
...
}
```

## 修复六

&emsp;&emsp;**问题6：** 当函数只有一个renturn的时候会反编译错误。

&emsp;&emsp;**解决6：**

```c++
 case OP_RETURN:
{
    ...
    // add by littleNA
    // 新增的if
    if (pc != 0)
    {
        for (i = a; i < limit; i++) {
                char* istr;
                if (i > a)
                        StringBuffer_add(str, ", ");
                istr = GetR(F, i);
                TRY(StringBuffer_add(str, istr));
        }
        TRY(AddStatement(F, str));
    }
    break;      
}

```

## 修复七

&emsp;&emsp;**问题7：** 部分table初始化会出错。

&emsp;&emsp;**解决7：**

```c++
char *GetR(Function * F, int r)
{
   if (IS_TABLE(r)) {
     // add by littleNA
        return "{ }";
    //  PrintTable(F, r, 0);
    //  if (error) return NULL;
   }
...
}
```

## 修复八

&emsp;&emsp;**问题8：** 可变参数部分解析出错，但是工具反编译时是不报错误的。

&emsp;&emsp;**解决8：** is_vararg为7时，F->freeLocal多加了一次：

```c++

   if (f->is_vararg==7) {
      TRY(DeclareVariable(F, "arg", F->freeLocal));
      F->freeLocal++;
   }
   // add by littleNA
   // 修改if为else if
   else if ((f->is_vararg&2) && (functionnum!=0)) {
      F->freeLocal++;
   }
```

## 修复九

&emsp;&emsp;**问题9：** 反编译工具输出的中文为url类型的字符（类似 “\230\176\148\231\150\151\230\156\175”），不是中文。

&emsp;&emsp;**解决9：** 在proto.c文件中的DecompileString函数中，注释掉default 转换字符串的函数：

```c++
char *DecompileString(const Proto * f, int n)
{
...
        default:
              //add by littleNA
//            if (*s < 32 || *s > 127) {
//               char* pos = &(ret[p]);
//               sprintf(pos, "\\%d", *s);
//               p += strlen(pos);
//            } else {
               ret[p++] = *s;
//            }
            break;
...
}
```

&emsp;&emsp;然后再下面3处增加判断的约束条件，因为中文字符的话，char字节是负数，这样isalpha和isalnum函数就会出错，所以增加约束条件，小于等于127：

```c++
void MakeIndex(Function * F, StringBuffer * str, char* rstr, int self)
{
...
   int dot = 0;
   /*
    * see if index can be expressed without quotes
    */
   if (rstr[0] == '\"') {

      // add by littleNA
      // (unsigned char)(rstr[1]) <= 127 &&
      if ((unsigned char)(rstr[1]) <= 127 && isalpha(rstr[1]) || rstr[1] == '_') {
         char *at = rstr + 1;
         dot = 1;
         while (*at != '"') {

            // add by littleNA
            // *(unsigned char*)at <= 127 &&
            if (*(unsigned char*)at <= 127 && !isalnum(*at) && *at != '_') {
               dot = 0;
               break;
            }
            at++;
         }
      }
   }
....
}


...
    case OP_TAILCALL:
    {
               // add by littleNA
               // (unsigned char)(*at) <= 127 &&
               while (at > astr && ((unsigned char)(*at) <= 127 && isalpha(*at) || *at == '_')) {
                  at--;
               }
    }
...
```

## 修复十

&emsp;&emsp;**问题10：** 反汇编失败。因为一些文件中含有很长的字符串，导致sprintf函数调用失败。

&emsp;&emsp;**解决10：** 增加缓存的大小：

```c++
void luaU_disassemble(const Proto* fwork, int dflag, int functions, char* name) {
 ...
                       // add by littleNA
                       // char lend[MAXCONSTSIZE+128];
                       char lend[MAXCONSTSIZE+2048];
...
}
```

## 修复十一

&emsp;&emsp;**问题11：** op_setlist操作码当b==0时，反编译失败。

&emsp;&emsp;**解决11：** 当遇到类似下面的lua语句时，反编译工具会失败，出现的情况在@lib_ui.lua文件中：

```lua
local a={func()}
```

&emsp;&emsp;汇编后的代码：

```c++
               a   b   c
[1] newtable   0   0   0    ; array=0, hash=0
[2] getglobal  1   0        ; func
[3] call       1   1   0
[4] setlist    0   0   1    ; index 1 to top
[5] return     0   1
```

&emsp;&emsp;出现的问题有2处，第一个是newtable，当b == 0 && c == 0时，反编译工具认为table是空的table，直接输出了table并且释放了table的内存，导致后面setlist初始化table时找不到内存而报错。

&emsp;&emsp;第二个是setlist有问题，当b==0时，其实是指寄存器a+1到栈顶（top）的值全部赋值于table，而反编译器没有对b==0的判断，加上就可以了。所以修改如下：

```c++
void StartTable(Function * F, int r, int b, int c)
{
   DecTable *tbl = NewTable(r, F, b, c);
   AddToList(&(F->tables), (ListItem *) tbl);
   F->Rtabl[r] = 1;
   F->Rtabl[r] = 1;
   if (b == 0 && c == 0) {

           // add by littleNA
           // for(){}
           for (int npc = F->pc + 1; npc < F->f->sizecode; npc++)
           {
                  Instruction i = F->f->code[npc];
                  OpCode o = GET_OPCODE(i);
                  if ((o != OP_SETLIST && o != OP_SETTABLE) && r == GETARG_A(i))
                  {
                          PrintTable(F, r, 1);
                          return;
                  }
                  else if ((o == OP_SETLIST || o == OP_SETTABLE) && r == GETARG_A(i))
                  {
                          return;
                  }
           }
      PrintTable(F, r, 1);
      if (error)
         return;
   }
}

void SetList(Function * F, int a, int b, int c)
{
...
   // add by littleNA
   // if(){}
   if (b == 0)
   {
           Instruction i = F->f->code[F->pc-1];
           OpCode o = GET_OPCODE(i);
           if (o == OP_CALL)
           {
                  int aa = GETARG_A(i);
                  for (i = a + 1; i < aa + 1; i++)
                  {
                          char* rstr = GetR(F, i);
                          if (error)
                                 return;
                          AddToTable(F, tbl, rstr, NULL);
                          if (error)
                                 return;
                  }
           }
           else
           {
                  for (i = 1;;i++) {
                          char* rstr = GetR(F, a + i);
                          if (rstr == NULL)
                                 return;
                          AddToTable(F, tbl, rstr, NULL);
                          if (error)
                                 return;
                  }
           }
   }
...
}
```

&emsp;&emsp;StartTable 增加的for循环表示，如果执行了newtable(r 0 0)，后面非初始化table的操作覆盖了r寄存器（把table覆盖了），那就表明new出来的table是空的，后面没有对table的赋值；如果后面有对r寄存器初始化，证明此时new出了的table不是空的，是可变参数的table。

&emsp;&emsp;SetList 增加的if表示，如果指令是call指令，那么将a+1到call指令寄存器aa的栈元素加入到table中（这里为何不是到栈顶的元素而是到aa的元素呢？因为call指令对应的是函数调用，反编译工具已经把函数调用的字符串解析到aa中了，这里跟实际运行可能有点不一样；else后面就是将a+1到栈顶的元素初始化到table中，直到GetR函数为空表示到栈顶了。

## 修复十二

&emsp;&emsp;**问题12：** 当一个函数开头只是局部变量声明，如：

```lua
function func()
     local a,b,c
     c = f(a,b)
     return c
end
```

&emsp;&emsp;第一行 local a,b,c 会反编译失败，导致后面的代码出现各种错误。

&emsp;&emsp;**解决12：**

```c++
void DeclareLocals(Function * F)
{
...
   for (i = startparams; i < F->f->sizelocvars; i++) {
      if (F->f->locvars[i].startpc == F->pc) {
             ...
             if (PENDING(r)) {...}
             // add by littleNA
             // else if(){}
             else if (locals == 0 && F->pc == 0)
             {
                     StringBuffer_add(str, LOCAL(i));
                     char *szR = GetR(F, r);
                     StringBuffer_add(rhs, szR==NULL?"nil":szR);
             }
             ...   
       }
   }
...
}
```

&emsp;&emsp;当变量的startpc 等于 当前pc，变量的个数为0并且当前pc为0，表示第一行声明了变量，添加的else if就是解析这种情况的（原来是直接报错不解析）。

&emsp;&emsp;（完）