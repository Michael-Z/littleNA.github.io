---
title: 2018看雪·京东AI CTF大挑战特别题 writeup
date: 2018-07-16 20:10:52
tags: 
  - ctf
  - writeup
  - AI
  - 看雪
categories: 解题报告
---

> &emsp;&emsp;非常荣幸，这次AI与CTF结合的比赛本人获得了第二名（估计很多大佬懒得做，都跑去打常规赛了）。这一篇文章是本人发在看雪的解题报告，现转载到个人博客。原地址 [请点击这里](https://bbs.pediy.com/thread-229564.htm)

# 前言
&emsp;&emsp;前不久自己也思考过能不能将热门的AI技术与CTF比赛结合起来，没想到就意外发现了这道题，感觉非常有趣�?

# 题目解析

&emsp;&emsp;首先，阅读题目，发现模型是使用深度学习来检测一段二进制代码中是否存在函数入口，存在的话将入口点标为1，否则为0。而题目需要我们对模型机进行微调，使得模型能够识别出一段不能识别的二进制代码的入口点。说白就是我们需要造一些样本，重新训练模型使得模型能够识别给定样本的函数入口点并保证不是入口点也能识别正确。题目提供了模型的文件和样本�?2个数据�?

&emsp;&emsp;接着，我们需要看看模型是使用什么框架生成的，查看模型文件的二进制代码，发现是hdf文件�?

{% asset_img 1.png %}

<!-- more -->

&emsp;&emsp;使用python的h5py工具解析，发现模型是基于theano工具的keras框架生成的，使用的RNN算法�?

{% asset_img 2.png %}

&emsp;&emsp;代码如下�?

```python
import h5py

def print_dateset(name,d):
    if type(d).__name__ == "Group":
        print("      {}".format(name))
        for name1, d1 in d.items():
            print_dateset(name1,d1)    
    else:
        print("      {}: {}".format(name, d.value.shape)) # 输出储存在Dataset中的层名称和权重
        print("      {}: {}".format(name, d.value))

def print_keras_wegiths(weight_file_path):
    f = h5py.File(weight_file_path)  # 读取weights h5文件返回File�?
    try:
        if len(f.attrs.items()):
            print("{} contains: ".format(weight_file_path))
            print("Root attributes:")
        for key, value in f.attrs.items():
            print("  {}: {}".format(key, value))  # 输出储存在File类中的attrs信息，一般是各层的名�?

        for layer, g in f.items():  # 读取各层的名称以及包含层信息的Group�?
            print("  {}".format(layer))
            print("    Attributes:")
            for key, value in g.attrs.items(): # 输出储存在Group类中的attrs信息，一般是各层的weights和bias及他们的名称
                print("      {}: {}".format(key, value))

            print("    Dataset:")
            for name, d in g.items(): # 读取各层储存具体信息的Dataset�?
                print_dateset(name,d)
    finally:
        f.close()

print_keras_wegiths("gcc_O2.h5")
```

&emsp;&emsp;之后使用keras自带的模型绘制接口，将模型结构图打印出来�?

{% asset_img 3.png %}

&emsp;&emsp;代码如下�?

```python
from keras.models import load_model
from keras.utils import plot_model

model = load_model("gcc_O2.h5")
plot_model(model, to_file='model.png',show_shapes=True)
```

&emsp;&emsp;知道了模型使用的框架，那么之后重新训练模型就非常方便了，再来看看样本点。观察发现，一段正常二进制代码应该会存在很多个0，而样本点存在很多�?1且没�?0，同时单字节存在几个256（单字节最大应该只�?255），所以这里的二进制代码是经过�?1运算后的代码，我们通过�?1再进行反汇编，看看函数的入口特征�?

```c
0048E000 >  31C0                  xor eax,eax                             
0048E002    83FA 0F               cmp edx,0xF
0048E005    0f94c0                sete al
0048E008 >  8D04C5 08000000       lea eax,dword ptr ds:[eax*8+0x8]
0048E00F    C3                    retn
0048E010 >  31C0                  xor eax,eax                             
0048E012    83FA 0F               cmp edx,0xF
0048E015    0f94c0                sete al
0048E018 >  8D04C5 09000000       lea eax,dword ptr ds:[eax*8+0x9]
0048E01F    C3                    retn
0048E020 >  90                    nop
0048E021    8DB426 00000000       lea esi,dword ptr ds:[esi]
0048E028 >  83EC 0C               sub esp,0xC
0048E02B    895C24 04             mov dword ptr ss:[esp+0x4],ebx
0048E02F    31DB                  xor ebx,ebx
0048E031    897424 08             mov dword ptr ss:[esp+0x8],esi
0048E035    89C6                  mov esi,eax                             
0048E037    0FB6041E              movzx eax,byte ptr ds:[esi+ebx]
0048E03B    E8 18FFFFFF           call 0048DF58
0048E040 >  83F8 14               cmp eax,0x14
0048E043    76 0B                 jbe 0048E050
0048E045    E8 7E3AFFFF           call 00481AC8
0048E04A    8DB6 00000000         lea esi,dword ptr ds:[esi]
0048E050 >  FF2485 A8910F08       jmp dword ptr ds:[eax*4+0x80F91A8]
0048E057    90                    nop
0048E058 >  B8 03000000           mov eax,0x3
0048E05D    8B7424 08             mov esi,dword ptr ss:[esp+0x8]
0048E061    01D8                  add eax,ebx
0048E063    8B5C24 04             mov ebx,dword ptr ss:[esp+0x4]
0048E067    83C4 0C               add esp,0xC
0048E06A    C3                    retn
0048E06B    90                    nop
0048E06C >  8D7426 00             lea esi,dword ptr ds:[esi]
0048E070 >  B8 02000000           mov eax,0x2
0048E075    8B7424 08             mov esi,dword ptr ss:[esp+0x8]
0048E079    01D8                  add eax,ebx
0048E07B    8B5C24 04             mov ebx,dword ptr ss:[esp+0x4]
0048E07F    83C4 0C               add esp,0xC
0048E082    C3                    retn
0048E083    90                    nop
0048E084 >  8D7426 00             lea esi,dword ptr ds:[esi]
0048E088 >  83C3 01               add ebx,0x1
0048E08B  ^ EB AA                 jmp short idaq.0048E037
0048E08D    8D76 00               lea esi,dword ptr ds:[esi]
0048E090 >  B8 01000000           mov eax,0x1
0048E095    8B7424 08             mov esi,dword ptr ss:[esp+0x8]
0048E099    01D8                  add eax,ebx
0048E09B    8B5C24 04             mov ebx,dword ptr ss:[esp+0x4]
0048E09F    83C4 0C               add esp,0xC
0048E0A2    C3                    retn
0048E0A3    90                    nop
0048E0A4 >  8D7426 00             lea esi,dword ptr ds:[esi]
0048E0A8 >  B8 05000000           mov eax,0x5
0048E0AD    8B7424 08             mov esi,dword ptr ss:[esp+0x8]
0048E0B1    01D8                  add eax,ebx
0048E0B3    8B5C24 04             mov ebx,dword ptr ss:[esp+0x4]
0048E0B7    83C4 0C               add esp,0xC
0048E0BA    C3                    retn
0048E0BB    8DB6 00000000         lea esi,dword ptr ds:[esi]
0048E0C1    8DBC27 00000000       lea edi,dword ptr ds:[edi]
```

&emsp;&emsp;题目提示说这一段代码的函数入口点是在下标为40的点，也就是上面所示的 0048E028 地址�? sub esp,0xC 这一句函数的入口�? 模型无法识别，这个函数反编译后的结果其实是一个switch结构，类似如下：

```c++
void test(int arg1)
{
    int a1,a2,a3;
    ...
    switch(arg1)
    {
        case :
            break;
        case :
            break;
        case :
            break;
        ...
    }
}
```

&emsp;&emsp;题目解析到这里，接下来说说如何解答�?

# 解题方法

&emsp;&emsp;首先，我们把样本点输入到模型中，看模型预测的结果，发现每个点输出一个包�?2个元素的向量，第1个表示不是入口点的概率，�?2个表示是入口点的概率。从输出的结果可以看出，除去�?40个点的概率是 [0.722�?0.278]，其他基本都�? [1,0]，说明模型差一点就能识别出函数的入口点，而其它的点也没有识别错误�?

&emsp;&emsp;模型预测的结果：

```python
[[[  1.00000000e+00   1.01599495e-09]
  [  1.00000000e+00   9.24199650e-09]
...
  [  1.00000000e+00   2.13964561e-13]
  [  1.00000000e+00   8.94351252e-17]
  [  1.00000000e+00   1.66032972e-13]
  [  7.22238600e-01   2.77761400e-01]       # 这个是原始的模型对下标为40的预测结�?
  [  1.00000000e+00   1.01078647e-19]
  [  1.00000000e+00   4.74433075e-21]
  [  1.00000000e+00   1.37062649e-18]
  [  1.00000000e+00   1.50506920e-25]
...
  [  1.00000000e+00   2.42857068e-14]]]
```

&emsp;&emsp;那么，最简单的办法就是将样本点随便改改，然后输入到模型重新训练，应该就能识别。（这里题目没有要求模型需要保证在原始的样本中保持某一个准确度�?

&emsp;&emsp;我这里将样本点的�?0个点 50 改成 49，也就是将第一句的 xor eax,eax 改成 xor al,al ，作为模型的一个训练样本，使用SGD作为优化方法，参数学习率 lr=0.0001, 动量momentum=0.9，使用的迭代次数�?10次，并且冻结除RNN的其他层，再重新训练，结果如下：

```python
Epoch 1/10

1/1 [==============================] - 0s 12ms/step - loss: 0.0064 - acc: 0.9950
Epoch 2/10

1/1 [==============================] - 0s 13ms/step - loss: 0.0063 - acc: 0.9950
Epoch 3/10

1/1 [==============================] - 0s 13ms/step - loss: 0.0060 - acc: 0.9950
Epoch 4/10

1/1 [==============================] - 0s 12ms/step - loss: 0.0057 - acc: 0.9950
Epoch 5/10

1/1 [==============================] - 0s 12ms/step - loss: 0.0053 - acc: 0.9950
Epoch 6/10

1/1 [==============================] - 0s 12ms/step - loss: 0.0048 - acc: 0.9950
Epoch 7/10

1/1 [==============================] - 0s 12ms/step - loss: 0.0044 - acc: 0.9950
Epoch 8/10

1/1 [==============================] - 0s 12ms/step - loss: 0.0039 - acc: 0.9950
Epoch 9/10

1/1 [==============================] - 0s 12ms/step - loss: 0.0035 - acc: 1.0000
Epoch 10/10

1/1 [==============================] - 0s 11ms/step - loss: 0.0031 - acc: 1.0000
[[[ 1.  0.]
  [ 1.  0.]
...
  [ 1.  0.]
  [ 1.  0.]
  [ 1.  0.]
  [ 0.  1.]     # 这个是重新训练的模型对下标为40的预测结�?
  [ 1.  0.]
  [ 1.  0.]
  [ 1.  0.]
  [ 1.  0.]
...
  [ 1.  0.]]]
```

&emsp;&emsp;代码如下�?

```python
from keras.optimizers import SGD
from keras.models import load_model
import numpy as np

def setup_to_finetune(model):
    for layer in model.layers:
     layer.trainable = False

    model.layers[1].trainable = True  # RNN�? 不冻�?
  model.compile(optimizer=SGD(lr=0.0001, momentum=0.9), loss='categorical_crossentropy', metrics=['accuracy'])

a = [49,193,132,251,16,16,149,193,142,5,198,9,1,1,1,196,50,193,132,251,16,16,149,193,142,5,198,10,1,1,1,196,145,142,181,39,1,1,1,1,132,237,13,138,93,37,5,50,220,138,117,37,9,138,199,16,183,5,31,233,25,256,256,256,132,249,21,119,12,233,127,59,256,256,142,183,1,1,1,1,256,37,134,169,146,16,9,145,185,4,1,1,1,140,117,37,9,2,217,140,93,37,5,132,197,13,196,145,142,117,39,1,185,3,1,1,1,140,117,37,9,2,217,140,93,37,5,132,197,13,196,145,142,117,39,1,132,196,2,236,171,142,119,1,185,2,1,1,1,140,117,37,9,2,217,140,93,37,5,132,197,13,196,145,142,117,39,1,185,6,1,1,1,140,117,37,9,2,217,140,93,37,5,132,197,13,196,142,183,1,1,1,1,142,189,40,1,1,1,1]
x_train = np.array([a])

b = [[1,0] for i in range(200)]
b[40] = [0,1]      # 设置�?40位为函数入口�?
y_train = np.array([b])

model = load_model("gcc_O2.h5")
setup_to_finetune(model)
model.fit(x_train,y_train,batch_size=1,epochs=10)    # 重新训练

a = [50,193,132,251,16,16,149,193,142,5,198,9,1,1,1,196,50,193,132,251,16,16,149,193,142,5,198,10,1,1,1,196,145,142,181,39,1,1,1,1,132,237,13,138,93,37,5,50,220,138,117,37,9,138,199,16,183,5,31,233,25,256,256,256,132,249,21,119,12,233,127,59,256,256,142,183,1,1,1,1,256,37,134,169,146,16,9,145,185,4,1,1,1,140,117,37,9,2,217,140,93,37,5,132,197,13,196,145,142,117,39,1,185,3,1,1,1,140,117,37,9,2,217,140,93,37,5,132,197,13,196,145,142,117,39,1,132,196,2,236,171,142,119,1,185,2,1,1,1,140,117,37,9,2,217,140,93,37,5,132,197,13,196,145,142,117,39,1,185,6,1,1,1,140,117,37,9,2,217,140,93,37,5,132,197,13,196,142,183,1,1,1,1,142,189,40,1,1,1,1]
x_test = np.array([a])

print(np.rint(model.predict(x_test)))      # 预测
model.save("gcc_O2_new.h5")       # 保存模型
```


# 结束�?
&emsp;&emsp;感觉这道题的逆向要求不是很高，然后深度学习算法的要求也不是很高，但是两者结合起来感觉挺有意思的。不过，没有其他限制的话，模型是可以过拟合的（只识别一个提供的样本点），为了避免模型过拟合，主办方其实可以提供一些样本，要求新的模型在这些样本下也能够保持准确度�?

[附件下载](工程附件.rar)