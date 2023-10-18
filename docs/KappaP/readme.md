## 简介

Kappa 系数检验 P 值的计算。

## 语法

### 必选参数

- [INDATA](#indata)
- [TABLE_DEF](#table_def)
- [OUTDATA](#outdata)

### 可选参数

- [STAT_NOTE](#stat_note)
- [WEIGHT](#weight)
- [KAPPA_TYPE](#kappa_type)
- [KAPPA_WEIGHT](#kappa_weight)
- [EXACT](#exact)
- [NULL_KAPPA](#null_kappa)
- [SIDES](#sides)
- [FORMAT](#format)
- [PLACEHOLDER](#placeholder)

### 调试参数

- [DEL_TEMP_DATA](#del_temp_data)

## 参数说明

### INDATA

**Syntax** : <_libname._>_dataset_(_dataset-options_)

指定用于定性分析的数据集，可包含数据集选项

_libname_: 数据集所在的逻辑库名称

_dataset_: 数据集名称

_dataset-options_: 数据集选项，兼容 SAS 系统支持的所有数据集选项

**Example** :

```sas
INDATA = ADSL
INDATA = SHKY.ADSL
INDATA = SHKY.ADSL(where = (FAS = "Y"))
```

---

### TABLE_DEF

**Syntax** :

- _variable-1\*variable-2_
- _variable-1_("_level-1_"<, "_level-2_"<, ...>>)\*_variable-2_("_level-1_"<, "_level-2_"<, ...>>)

指定 $R\times C$ 表的定义，其中 _`variable-1`_ 表示 $R\times C$ 表的行变量，_`variable-2`_ 表示 $R\times C$ 表的列变量，_`level-i`_ 表示行（列）的具体分类名称。

**Caution** :

1. 参数 `TABLE_DEF` 指定的 $R\times C$ 表的大小必须不小于 $2\times 2$；
2. 参数 `TABLE_DEF` 指定的行列变量的分类名称可以不完全相同，但由于 Kappa 系数的检验基于方形表，因此宏程序会试图求取行列变量中各分类的并集，然后在此基础上构建方形表。对于加权 Kappa 系数的检验，行列变量的顺序有可能会影响最终的计算结果，为了避免歧义，在计算加权 Kappa 系数进行检验时，参数 `TABLE_DEL` 应当显式指定行列变量的各分类名称，且行列变量应当指定相同的分类名称。例如：`TABLE_DEF = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效")`。

**Example** :

```sas
TABLE_DEF = %str(TSTP*TSTC)
TABLE_DEF = %str(TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"))
```

---

### OUTDATA

**Syntax** : <_libname._>_dataset_(_dataset-options_)

指定统计结果输出的数据集，可包含数据集选项，用法同参数 [INDATA](#indata)。

输出数据集有 2 个变量，具体如下：

| 变量名 | 含义                  |
| ------ | --------------------- |
| ITEM   | 指标名称              |
| VALUE  | Kappa 系数检验的 P 值 |

**Example** :

```sas
OUTDATA = T1
```

---

### STAT_NOTE

**Syntax** : _string(s)_

指定 Kappa 系数检验的 P 值的名称，指定的名称将输出至参数 `OUTDATA` 指定的数据集中的 ITEM 列。

**Default** : %str(kappa P 值)

**Example** :

```sas
STAT_NOTE = %str(P value)
```

---

### WEIGHT

**Syntax** : _variable_

指定计算频数的权重变量。

**Default** : #NULL

默认情况下，数据集中的每一条观测的权重均为 1。

**Caution** :

1. 参数 `WEIGHT` 不允许指定参数 `INDATA` 指定的数据集中不存在的变量；
2. 参数 `WEIGHT` 不允许指定字符型变量。

**Example** :

```sas
WEIGHT = FREQ
```

---

### KAPPA_TYPE

**Syntax** : #SIMPLE|#WEIGHTED

指定计算 Kappa 系数的类型。

**Default** : #SIMPLE

默认情况下，宏程序将对简单 Kappa 系数进行检验。

**Example** :

```sas
KAPPA_TYPE = #WEIGHTED
```

---

### KAPPA_WEIGHT

**Syntax** : #_kappa_weight_keyword_

指定对加权 Kappa 系数进行检验时使用的权重类型，_`kappa_weight_keyword`_ 可以是以下权重类型之一：

| 权重类型          | 简写 |
| ----------------- | ---- |
| CICCHETTI-ALLISON | CA   |
| FLEISS-COHEN      | FC   |

**Default** : #AUTO

默认情况下，当参数 `KAPPA_TYPE` 指定了对加权 Kappa 系数进行检验时，参数 `KAPPA_WEIGHT` 的默认值为 `CA`，表示使用 Cicchetti-Allison 权重进行加权 Kappa 系数的计算。

**Caution** :

1. 参数 `KAPPA_TYPE` 未指定对加权 Kappa 系数进行检验时，参数 `KAPPA_WEIGHT` 的值将被忽略；

**Example** :

```sas
KAPPA_WEIGHT = FC
```

---

### EXACT

**Syntax** : TRUE|FALSE

指定是否进行精确检验。

**Default** : FALSE

默认情况下，宏程序将不进行精确检验。

**Example** :

```sas
EXACT = TRUE
```

---

### NULL_KAPPA

**Syntax** : _numeric_

指定零假设下的 Kappa 系数。

**Default** : #AUTO

当参数 `EXACT` 指定为 `FALSE` 时，`NULL_KAPPA` 的默认值为 0；

当参数 `EXACT` 指定为 `TRUE` 时，`NULL_KAPPA` 的值将被忽略；

**Example** :

```sas
NULL_KAPPA = 0.89
```

---

### SIDES

**Syntax** : 1|2

指定假设检验的类型，1 表示单侧检验，2 表示双侧检验。

**Default** : 2

默认情况下，宏程序将计算双侧检验下的 P 值。

**Caution** :

1. 当参数 `SIDES = 1` 时，宏程序将根据以下情况决定进行左侧检验或右侧检验：
   - 当计算的样本 Kppa 系数**小于**参数 `NULL_KAPPA` 指定的零假设下的 Kappa 系数时，宏程序将进行**左侧**检验；
   - 当计算的样本 Kppa 系数**大于**参数 `NULL_KAPPA` 指定的零假设下的 Kappa 系数时，宏程序将进行**右侧**检验；
   - 当计算的样本 Kppa 系数**等于**参数 `NULL_KAPPA` 指定的零假设下的 Kappa 系数时，宏程序将进行**左侧**检验。

**Example** :

```sas
SIDES = 1
```

### FORMAT

**Syntax** : _format_

指定对 Kappa 系数进行检验的 P 值的输出格式。

**Default** : PVALUE6.3

默认情况下，Kappa 系数假设检验的 P 值的输出格式为 `PVALUE6.3`。

**Example** :

```sas
FORMAT = 5.3
```

---

### PLACEHOLDER

**Syntax** : _string_(_s_)

指定当无法计算 Kappa 系数导致假设检验无法进行时，输出数据集中显示的字符（串）。

**Default** : `%str(-)`

**Example** :

```sas
PLACEHOLDER = %str(不适用)
```

---

### DEL_TEMP_DATA

**Syntax** : TRUE|FALSE

指定是否删除中间数据集。默认情况下，宏程序将删除运行过程中生成的所有中间数据集。

**Default** : TRUE

## 例子

### 打开帮助文档

```sas
%KappaP();
%KappaP(help);
```

### 一般用法

```sas
%KappaP(indata = adeff(where = (CMPTFL = "Y")),
        table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
        outdata = t1);
```

### 指定统计量名称

```sas
%KappaP(indata = adeff(where = (CMPTFL = "Y")),
        table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
        outdata = t1,
        stat_note = %str(Kappa P));
```

### 指定权重变量

```sas
data adeff;
    set temp.adeff;
    freq = _n_;
run;

%KappaP(indata = adeff(where = (CMPTFL = "Y")),
        table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
        outdata = t1,
        weight = freq);
```

### 指定计算 Kappa 系数的类型

```sas
%KappaP(indata = adeff(where = (CMPTFL = "Y")),
        table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
        outdata = t1,
        kappa_type = #weighted);
```

### 指定计算加权 Kappa 系数时使用的权重类型

```sas
%KappaP(indata = adeff(where = (CMPTFL = "Y")),
        table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
        outdata = t1,
        kappa_type = #weighted,
        kappa_weight = fleiss-cohen);
```

### 指定精确检验

```sas
%KappaP(indata = adeff(where = (CMPTFL = "Y")),
        table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
        outdata = t1,
        kappa_type = #weighted,
        kappa_weight = fleiss-cohen,
        exact = true);
```

### 指定零假设下的 Kappa 系数

```sas
%KappaP(indata = adeff(where = (CMPTFL = "Y")),
        table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
        outdata = t1,
        exact = false,
        null_kappa = 0.89);
```

### 指定假设检验的类型

```sas
%KappaP(indata = adeff(where = (CMPTFL = "Y")),
        table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
        outdata = t1,
        null_kappa = 0.89,
        sides = 1);
```

### 指定 P 值的输出格式

```sas
proc format;
    picture spvalue(round  max = 6) /*P值一般原则*/
            low - < 0.001 = "<0.001"(noedit)
            other = "9.999";
run;
%KappaP(indata = adeff(where = (CMPTFL = "Y")),
        table_def = TSTP("阳性", "阴性", "无效")*TSTC("阳性", "阴性", "无效"),
        outdata = t1,
        format = spvalue.);
```

### 指定无法进行假设检验时显示的字符（串）

```sas
%KappaP(indata = adeff(where = (CMPTFL = "Y")),
        table_def = TSTP("金", "木", "水", "火", "土")*TSTC("甲", "乙", "丙", "丁", "戊"),
        outdata = t1,
        placeholder = %str(-));
```
