## 简介

用于频数统计的 SAS 宏程序。

支持以下编码环境：

- [GBK](./gbk/)
- [UTF8](./utf8/)

## 语法

### 必选参数

- [CALL](#call)

### 可选参数

- [_Parameters_](#parameters)

## 参数说明

### CALL

**Syntax** : _call_specification_

指定需要调用的子程序名称，目前可用的 _`call_specification`_ 如下：

| call_specification | 功能                |
| ------------------ | ------------------- |
| Binomial           | 二项分布率及其 CI   |
| KappaCI            | Kappa 系数及其 CI   |
| KappaP             | Kappa 系数检验 P 值 |
| RiskDiff           | 率差及其 CI         |

**Example** :

```sas
CALL = BinomialCI
```

---

### _Parameter(s)_

**Syntax** : _parameter-1_ = _value-1_ <, _parameter-2_ = _value-2_ <, ...>>

可变参数列表的参数数量和名称不是固定的，它们取决于参数 [CALL](#call) 指定的子程序，不同子程序支持的参数列表都是不一样的，详情可查看各子程序相应文档：

- [BinomialCI](./docs/BinomialCI/readme.md)
- [KappaCI](./docs/KappaCI/readme.md)
- [KappaP](./docs/KappaP/readme.md)
- [RiskDiff](./docs/RiskDiff/readme.md)

> [!NOTE]
>
> - 若指定的参数不受子程序支持，则该参数将被忽略。

## 调用示例

### 打开帮助文档

```sas
%FreqStatKit();
%FreqStatKit(help);
```

### 一般用法

```sas
%FreqStatKit(call = binomialci,
             indata = adeff,
             cond_pos = %str(TSTP = "阳性" and TSTC = "阳性"),
             cond_neg = %str(TSTP ^= "阳性" and TSTC = "阳性"),
             stat_note = %str(阳性符合率),
             outdata = t1);

%FreqStatKit(call = kappaci,
             indata = adeff(where = (CMPTFL = "Y")),
             table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
             outdata = t2);

%FreqStatKit(call = kappap,
             indata = adeff(where = (CMPTFL = "Y")),
             table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
             outdata = t3);

%FreqStatKit(call = RiskDiff,
             indata = analysis,
             group = arm("试验组" - "对照组"),
             response = nyha("是"),
             stat_note = '率差(95%CI)',
             outdata = t4);
```
