/*
===================================
Macro Name: KappaP
Macro Label: Kappa 系数的检验P值
Author: wtwang
Version Date: 2023-01-13 V1.0
              2023-12-06 V1.1
===================================
*/

%macro KappaP(INDATA, TABLE_DEF, OUTDATA, STAT_NOTE = %str(Kappa P值), WEIGHT = #NULL, KAPPA_TYPE = #SIMPLE, KAPPA_WEIGHT = #AUTO,
              EXACT = FALSE, NULL_KAPPA = #AUTO, SIDES = 2, FORMAT = PVALUE6.3, PLACEHOLDER = %str(-), DEL_TEMP_DATA = TRUE) /des = "Kappa 系数检验的P值" parmbuff;
/*
INDATA:          分析数据集名称
TABLE_DEF:       R*C表的定义
STAT_NOTE:       统计量的名称, 例如：STAT_NOTE = %str(Kappa P值)
OUTDATA:         输出数据集名称
WEIGHT:          权重变量
KAPPA_TYPE:      Kappa值的类型（简单Kappa, 加权Kappa）
KAPPA_WEIGHT:    Kappa权重的类型（Cicchetti-Allison, Fleiss-Cohen）
EXACT:           是否进行精确检验
NULL_KAPPA:      零假设下的Kappa系数
SIDES:           检验类型（1: 单侧检验, 2: 双侧检验）
PLACEHOLDER:     占位符，当表为空或表过于稀疏时，无法计算Kappa值，输出占位符到数据集中
DEL_TEMP_DATA:   删除中间数据集
*/

    /*打开帮助文档*/
    %if %qupcase(%superq(SYSPBUFF)) = %bquote((HELP)) or %qupcase(%superq(SYSPBUFF)) = %bquote(()) %then %do;
        /*
        %let host = %bquote(192.168.0.199);
        %let help = %bquote(\\&host\统计部\SAS宏\08 FreqStatKit\05 帮助文档\KappaP\readme.html);
        %if %sysfunc(system(ping &host -n 1 -w 10)) = 0 %then %do;
            %if %sysfunc(fileexist("&help")) %then %do;
                X explorer "&help";
            %end;
            %else %do;
                X mshta vbscript:msgbox("帮助文档不在线, 目标文件可能已被移动或删除！Orz",48,"提示")(window.close);
            %end;
        %end;
        %else %do;
                X mshta vbscript:msgbox("帮助文档不在线, 因为无法连接到服务器！ Orz",48,"提示")(window.close);
        %end;
        */
        X explorer "https://github.com/Snoopy1866/FreqStatKit/blob/main/docs/KappaP/readme.md";
        %goto exit;
    %end;

    /*----------------------------------------------初始化----------------------------------------------*/
    /*统一参数大小写*/
    %let indata               = %sysfunc(strip(%bquote(&indata)));
    %let table_def            = %sysfunc(strip(%bquote(&table_def)));
    %let stat_note            = %sysfunc(strip(%bquote(&stat_note)));
    %let outdata              = %sysfunc(strip(%bquote(&outdata)));
    %let weight               = %upcase(%sysfunc(strip(%bquote(&weight))));
    %let kappa_type           = %upcase(%sysfunc(strip(%bquote(&kappa_type))));
    %let kappa_weight         = %upcase(%sysfunc(strip(%bquote(&kappa_weight))));
    %let exact                = %upcase(%sysfunc(strip(%bquote(&exact))));
    %let null_kappa           = %upcase(%sysfunc(strip(%bquote(&null_kappa))));
    %let format               = %upcase(%sysfunc(strip(%bquote(&format))));
    %let del_temp_data        = %upcase(%sysfunc(strip(%bquote(&del_temp_data))));

    /*声明局部变量*/
    %local i j;

    /*----------------------------------------------参数检查----------------------------------------------*/
    /*INDATA*/
    %if %superq(indata) = %bquote() %then %do;
        %put ERROR: 未指定分析数据集！;
        %goto exit;
    %end;
    %else %do;
        %let reg_indata_id = %sysfunc(prxparse(%bquote(/^(?:([A-Za-z_][A-Za-z_\d]*)\.)?([A-Za-z_][A-Za-z_\d]*)(?:\((.*)\))?$/)));
        %if %sysfunc(prxmatch(&reg_indata_id, %bquote(&indata))) = 0 %then %do;
            %put ERROR: 参数 INDATA = %bquote(&indata) 格式不正确！;
            %goto exit;
        %end;
        %else %do;
            %let libname_in = %upcase(%sysfunc(prxposn(&reg_indata_id, 1, %superq(indata))));
            %let memname_in = %upcase(%sysfunc(prxposn(&reg_indata_id, 2, %superq(indata))));
            %let dataset_options_in = %sysfunc(prxposn(&reg_indata_id, 3, %superq(indata)));
            %if &libname_in = %bquote() %then %let libname_in = WORK; /*未指定逻辑库，默认为WORK目录*/
            proc sql noprint;
                select * from DICTIONARY.MEMBERS where libname = "&libname_in";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: &libname_in 逻辑库不存在！;
                %goto exit;
            %end;
            proc sql noprint;
                select * from DICTIONARY.MEMBERS where libname = "&libname_in" and memname = "&memname_in";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: 在 &libname_in 逻辑库中没有找到 &memname_in 数据集！;
                %goto exit;
            %end;
        %end;
    %end;
    %put NOTE: 分析数据集被指定为 &libname_in..&memname_in;


    /*TABLE_DEF*/
    %if %superq(table_def) = %bquote() %then %do;
        %put ERROR: 参数 TABLE_DEF 为空！;
        %goto exit;
    %end;
    %else %do;
        %let reg_table_def_expr = %bquote(/^([A-Za-z_][A-Za-z_\d]*)(?:\(\s*(".*"(?:[\s,]+".*")*)?\s*\))?\s*\*\s*([A-Za-z_][A-Za-z_\d]*)(?:\(\s*(".*"(?:[\s,]+".*")*)?\s*\))?$/);
        %let reg_table_def_id = %sysfunc(prxparse(&reg_table_def_expr));
        %if %sysfunc(prxmatch(&reg_table_def_id, %bquote(&table_def))) = 0 %then %do;
            %put ERROR: 参数 TABLE_DEF 格式不正确！;
            %goto exit;
        %end;
        %else %do;
            %let table_row_var = %upcase(%sysfunc(prxposn(&reg_table_def_id, 1, %bquote(&table_def))));
            %let table_row_level = %sysfunc(prxposn(&reg_table_def_id, 2, %bquote(&table_def)));
            %let table_col_var = %upcase(%sysfunc(prxposn(&reg_table_def_id, 3, %bquote(&table_def))));
            %let table_col_level = %sysfunc(prxposn(&reg_table_def_id, 4, %bquote(&table_def)));

            /*行列变量存在性检测*/
            %let IS_TABLE_DEF_VAR_EXIST = TRUE;
            proc sql noprint;
                select type into :type from DICTIONARY.COLUMNS where libname = "&libname_in" and memname = "&memname_in" and upcase(name) = "&table_row_var";
            quit;
            %if &SQLOBS = 0 %then %do; /*数据集中没有找到行变量*/
                %put ERROR: 在 &libname_in..&memname_in 中没有找到行变量 &table_row_var;
                %let IS_TABLE_DEF_VAR_EXIST = FALSE;
            %end;

            proc sql noprint;
                select type into :type from DICTIONARY.COLUMNS where libname = "&libname_in" and memname = "&memname_in" and upcase(name) = "&table_col_var";
            quit;
            %if &SQLOBS = 0 %then %do; /*数据集中没有找到列变量*/
                %put ERROR: 在 &libname_in..&memname_in 中没有找到列变量 &table_col_var;
                %let IS_TABLE_DEF_VAR_EXIST = FALSE;
            %end;

            %if &IS_TABLE_DEF_VAR_EXIST = FALSE %then %do;
                %goto exit;
            %end;
        %end;
    %end;


    /*STAT_NOTE*/
    %if %superq(stat_note) = %bquote() %then %do;
        %put ERROR: 参数 STAT_NOTE 为空！;
        %goto exit;
    %end;


    /*OUTDATA*/
    %if %superq(outdata) = %bquote() %then %do;
        %put ERROR: 参数 OUTDATA 为空！;
        %goto exit;
    %end;
    %else %do;
        %if %bquote(%upcase(&outdata)) = %bquote(#AUTO) %then %do;
            %let outdata = RES_&var_name;
        %end;
 
        %let reg_outdata_id = %sysfunc(prxparse(%bquote(/^(?:([A-Za-z_][A-Za-z_\d]*)\.)?([A-Za-z_][A-Za-z_\d]*)(?:\((.*)\))?$/)));
        %if %sysfunc(prxmatch(&reg_outdata_id, %bquote(&outdata))) = 0 %then %do;
            %put ERROR: 参数 OUTDATA = %bquote(&outdata) 格式不正确！;
            %goto exit;
        %end;
        %else %do;
            %let libname_out = %upcase(%sysfunc(prxposn(&reg_outdata_id, 1, %superq(outdata))));
            %let memname_out = %upcase(%sysfunc(prxposn(&reg_outdata_id, 2, %superq(outdata))));
            %let dataset_options_out = %sysfunc(prxposn(&reg_outdata_id, 3, %superq(outdata)));
            %if &libname_out = %bquote() %then %let libname_out = WORK; /*未指定逻辑库，默认为WORK目录*/
            proc sql noprint;
                select * from DICTIONARY.MEMBERS where libname = "&libname_out";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: &libname_out 逻辑库不存在！;
                %goto exit;
            %end;
        %end;
        %put NOTE: 输出数据集被指定为 &libname_out..&memname_out;
    %end;

    
    /*WEIGHT*/
    %if %superq(weight) ^= #NULL %then %do;
        %let reg_weight_id = %sysfunc(prxparse(%bquote(/^[A-Za-z_][A-Za-z_\d]*$/)));
        %if %sysfunc(prxmatch(&reg_weight_id, %bquote(&weight))) = 0 %then %do;
            %put ERROR: 参数 WEIGHT = %bquote(&weight) 格式不正确！;
            %goto exit;
        %end;
        %else %do;
            proc sql noprint;
                select type into :type from DICTIONARY.COLUMNS where libname = "&libname_in" and memname = "&memname_in" and upcase(name) = "&weight";
            quit;
            %if &SQLOBS = 0 %then %do; /*数据集中没有找到变量*/
                %put ERROR: 在 &libname_in..&memname_in 中没有找到权重变量 &weight;
                %goto exit;
            %end;
            %else %do;
                %if %bquote(&type) ^= num %then %do;
                    %put ERROR: 参数 WEIGHT 指定的权重变量 %bquote(&weight) 不是数值型的！;
                    %goto exit;
                %end;
            %end;
        %end;
    %end;


    /*KAPPA_TYPE*/
    %if %superq(kappa_type) = %bquote() %then %do;
        %put ERROR: 参数 KAPPA_TYPE 为空！;
        %goto exit;
    %end;

    %if %superq(kappa_type) = #SIMPLE %then %do;
        %put NOTE: 将计算简单 Kappa 系数！;
    %end;
    %else %if %superq(kappa_type) = #WEIGHTED %then %do;
        %put NOTE: 将计算加权 Kappa 系数！;
    %end;
    %else %do;
        %put ERROR: 参数 KAPPA_TYPE 必须是 #SIMPLE 或 #WEIGHTED ！;
        %goto exit;
    %end;


    /*KAPPA_WEIGHT*/
    %if %superq(kappa_type) = #SIMPLE %then %do;
        %if %superq(kappa_weight) ^= %bquote() and %superq(kappa_weight) ^= #AUTO %then %do;
            %put WARNING: 未计算加权 Kappa 系数，参数 KAPPA_WEIGHT 已被忽略！;
        %end;
    %end;
    %else %if %superq(kappa_type) = #WEIGHTED %then %do;
        %if %superq(kappa_weight) = #AUTO %then %do;
            %put NOTE: 未指定权重类型，默认使用 Cicchetti-Allison 权重进行计算！;
            %let kappa_weight = CA;
        %end;
        %else %if %superq(kappa_weight) = CA or %superq(kappa_weight) = %bquote(CICCHETTI-ALLISON) %then %do;
            %let kappa_weight = CA;
        %end;
        %else %if %superq(kappa_weight) = FC or %superq(kappa_weight) = %bquote(FLEISS-COHEN) %then %do;
            %let kappa_weight = FC;
        %end;
        %else %do;
            %put ERROR: 参数 KAPPA_WEIGHT 指定的权重类型 %bquote(&KAPPA_WEIGHT) 不存在或不受支持，受支持的权重类型如下：;
            %put ERROR- %bquote(CA, CICCHETTI-ALLISON);
            %put ERROR- %bquote(FC, FLEISS-COHEN);
            %goto exit;
        %end;
    %end;


    /*EXACT*/
    %if %superq(exact) = %bquote() %then %do;
        %put ERROR: 参数 EXACT 为空！;
        %goto exit;
    %end;

    %if %superq(exact) ^= TRUE and %superq(exact) ^= FALSE %then %do;
        %put ERROR: 参数 EXACT 必须是 TRUE 或 FALSE！;
        %goto exit;
    %end;


    /*NULL_KAPPA*/
    %if %superq(null_kappa) = %bquote() %then %do;
        %put ERROR: 参数 NULL_KAPPA 为空！;
        %goto exit;
    %end;

    %if %bquote(&exact) = TRUE %then %do;
        %if %superq(null_kappa) ^= #AUTO %then %do;
            %put WARNING: 精确检验不支持指定零假设下的 Kappa 值，参数 NULL_KAPPA 已被忽略！;
            %let null_kappa = #AUTO;
        %end;
    %end;
    %else %do;
        %if %superq(null_kappa) = #AUTO %then %do;
            %let null_kappa = 0;
        %end;
        %else %do;
            %let reg_null_kappa_id = %sysfunc(prxparse(%bquote(/^-?\d+(?:\.\d*)?$/)));
            %if %sysfunc(prxmatch(&reg_null_kappa_id, %superq(null_kappa))) = 0 %then %do;
                %put ERROR: 参数 NULL_KAPPA 格式不正确！;
                %goto exit;
            %end;
            %else %do;
                %if %sysevalf(&null_kappa) < -1 or %sysevalf(&null_kappa) > 1 %then %do;
                    %put ERROR: 零假设下的 Kappa 值必须在 -1 和 1 之间！;
                    %goto exit;
                %end;
            %end;
        %end;
    %end;
    


    /*SIDES*/
    %if %superq(sides) = %bquote() %then %do;
        %put ERROR: 参数 SIDES 为空！;
        %goto exit;
    %end;

    %if %superq(sides) ^= 1 and %superq(sides) ^= 2 %then %do;
        %put ERROR: 参数 SIDES 必须是 1（单侧检验） 或 2（双侧检验）！;
        %goto exit;
    %end;


    /*FORMAT*/
    %if %bquote(&format) = %bquote() %then %do;
        %put ERROR: 试图指定参数 FORMAT 为空！;
        %goto exit;
    %end;

    %let reg_format = %bquote(/^((\$?[A-Za-z_]+(?:\d+[A-Za-z_]+)?)(?:\.|\d+\.\d*)|\$\d+\.|\d+\.\d*)$/);
    %let reg_format_id = %sysfunc(prxparse(&reg_format));
    %if %sysfunc(prxmatch(&reg_format_id, &format)) = 0 %then %do;
        %put ERROR: 参数 FORMAT 格式不正确！;
        %goto exit;
    %end;
    %else %do;
        %let format_base = %sysfunc(prxposn(&reg_format_id, 2, &format));
        %if %bquote(&format_base) ^= %bquote() %then %do;
            proc sql noprint;
                select * from DICTIONARY.FORMATS where fmtname = "&format_base" and fmttype = "F";
            quit;
            %if &SQLOBS = 0 %then %do;
                %put ERROR: 输出格式 &format 不存在！;
                %goto exit;
            %end;
        %end;
    %end;


    /*DEL_TEMP_DATA*/
    %if %superq(del_temp_data) ^= TRUE and %superq(del_temp_data) ^= FALSE %then %do;
        %put ERROR: 参数 DEL_TEMP_DATA 必须是 TRUE 或 FALSE！;
        %goto exit;
    %end;

    /*----------------------------------------------主程序----------------------------------------------*/
    /*1. 复制分析数据*/
    proc sql noprint;
        create table temp_indata as
            select * from &libname_in..&memname_in(%superq(dataset_options_in));
    quit;


    /*2. 拆分行分类*/
    %if %superq(table_row_level) = %bquote() %then %do;
        proc sql noprint;
            create table temp_distinct_row_var as
                select
                    distinct &table_row_var
                from &libname_in..&memname_in(%superq(dataset_options_in)) order by &table_row_var;
            select &table_row_var into :table_row_level_1 - from temp_distinct_row_var;
            %let table_row_level_n = &SQLOBS;
        quit;
    %end;
    %else %do;
        %let table_row_level_n = %sysfunc(kcountw(%superq(table_row_level), %bquote(, ), %bquote(q)));
        %let reg_table_row_level_unit_expr = %bquote([\s,]+"(.*)");

        %if &table_row_level_n = 1 %then %do;
            %let reg_table_row_level_expr = %bquote(/^"(.*)"$/);
        %end;
        %else %do;
            %let reg_table_row_level_expr = %bquote(/^"(.*)"%sysfunc(repeat(%bquote(&reg_table_row_level_unit_expr), %eval(&table_row_level_n - 2)))$/);
        %end;
        %let reg_table_row_level_id = %sysfunc(prxparse(&reg_table_row_level_expr));

        %if %sysfunc(prxmatch(&reg_table_row_level_id, %superq(table_row_level))) = 0 %then %do;
            %put ERROR: 已检测到行变量 &table_row_var 的 &table_row_level_n 个分类，但在进一步拆分各分类时发生了意料之外的错误！;
            %goto exit;
        %end;
        %else %do;
            %do i = 1 %to &table_row_level_n;
                %let table_row_level_&i = %sysfunc(prxposn(&reg_table_row_level_id, &i, %superq(table_row_level)));
            %end;
        %end;
    %end;


    /*3. 拆分列分类*/
    %if %superq(table_col_level) = %bquote() %then %do;
        proc sql noprint;
            create table temp_distinct_col_var as
                select
                    distinct &table_col_var
                from &libname_in..&memname_in(%superq(dataset_options_in)) order by &table_col_var;
            select &table_col_var into :table_col_level_1 - from temp_distinct_col_var;
            %let table_col_level_n = &SQLOBS;
        quit;
    %end;
    %else %do;
        %let table_col_level_n = %sysfunc(kcountw(%superq(table_col_level), %bquote(, ), %bquote(q)));
        %let reg_table_col_level_unit_expr = %bquote([\s,]+"(.*)");

        %if &table_col_level_n = 1 %then %do;
            %let reg_table_col_level_expr = %bquote(/^"(.*)"$/);
        %end;
        %else %do;
            %let reg_table_col_level_expr = %bquote(/^"(.*)"%sysfunc(repeat(%bquote(&reg_table_col_level_unit_expr), %eval(&table_col_level_n - 2)))$/);
        %end;
        %let reg_table_col_level_id = %sysfunc(prxparse(&reg_table_col_level_expr));

        %if %sysfunc(prxmatch(&reg_table_col_level_id, %superq(table_col_level))) = 0 %then %do;
            %put ERROR: 已检测到行变量 &table_col_var 的 &table_col_level_n 个分类，但在进一步拆分各分类时发生了意料之外的错误！;
            %goto exit;
        %end;
        %else %do;
            %do i = 1 %to &table_col_level_n;
                %let table_col_level_&i = %sysfunc(prxposn(&reg_table_col_level_id, &i, %superq(table_col_level)));
            %end;
        %end;
    %end;


    /*4. 行、列分类取并集，使R*C表统一成方阵*/
    proc sql noprint;
        create table temp_distinct_var (var char(200), len num);
        %do i = 1 %to &table_row_level_n;
            select var from temp_distinct_var where var = "&&table_row_level_&i";
            %if &SQLOBS = 0 %then %do;
                insert into temp_distinct_var values("&&table_row_level_&i", %length(&&table_row_level_&i));
            %end;
        %end;
        %do i = 1 %to &table_col_level_n;
            select var from temp_distinct_var where var = "&&table_col_level_&i";
            %if &SQLOBS = 0 %then %do;
                insert into temp_distinct_var values("&&table_col_level_&i", %length(&&table_col_level_&i));
            %end;
        %end;

        select var into :table_level_1 - from temp_distinct_var;
        %let table_level_n = &SQLOBS;
        select max(len) into :len_max from temp_distinct_var;
    quit;

    /*行列分类取并集后的方阵大小检测*/
    %if &table_level_n < 2 %then %do;
        %put ERROR: 必须指定大小为 2×2 或以上的表格！;
        %goto exit_with_tempdata_created;
    %end;



    /*5. 判断R*C表是否为空表，如为空表则提前结束计算*/
    proc sql noprint;
        select count(*) into :freq_all from temp_indata where &table_row_var in (select var from temp_distinct_var) and
                                                              &table_col_var in (select var from temp_distinct_var);
        %if &freq_all = 0 %then %do;
            %put NOTE: 表为空，未对 Kappa 值进行检验！;
            %let kappap = %superq(placeholder);
            %goto temp_out;
        %end;
    quit;


    /*6. 显示方阵图形*/
    %if &kappa_type = #SIMPLE %then %do;
        %put NOTE: 将基于以下表格对简单 Kappa 系数进行检验:;
    %end;
    %else %if &kappa_type = #WEIGHTED %then %do;
        %put NOTE: 将基于以下表格对加权 Kappa 系数进行检验, 注意：行列分类的顺序将影响加权 Kappa 系数的计算结果，进而影响对加权 Kappa 系数进行检验的 P 值，请确认表格中行列分类的顺序准确无误！;
    %end;

    %let note_table_line_0 = %bquote(%sysfunc(repeat(%bquote( ), %eval(&len_max - 1))));
    %do i = 1 %to &table_level_n;
        %if %bquote(&&table_level_&i) = %bquote() %then %do;
            %let note_table_line_0 = %superq(note_table_line_0)%bquote(|)%bquote( );
        %end;
        %else %do;
            %let note_table_line_0 = %superq(note_table_line_0)%bquote(|)%bquote(&&table_level_&i);
        %end;
    %end;
    %let note_table_line_0 = %superq(note_table_line_0)%bquote(|);
    %put NOTE: %superq(note_table_line_0);

    %do i = 1 %to &table_level_n;
        %let note_table_line_&i = %bquote(%sysfunc(putc(%bquote(&&table_level_&i), $&len_max..)));
        %do j = 1 %to &table_level_n;
            %let note_table_line_&i = %superq(note_table_line_&i)%bquote(|)%bquote(%sysfunc(repeat(%bquote(_), %sysfunc(max(%eval(%length(%bquote(&&table_level_&j)) - 1), 0)))));
        %end;
        %let note_table_line_&i = %superq(note_table_line_&i)%bquote(|);
        %put NOTE- %superq(note_table_line_&i);
    %end;

    /*2*2表的加权Kappa系数与简单Kappa系数假设检验结果一致，发出警告信息*/
    %if &kappa_type = #WEIGHTED %then %do;
        %if &table_row_level_n = 2 and &table_col_level_n = 2 %then %do;
            %put WARNING: 加权 Kappa 系数对于 2×2 表的假设检验结果与简单 Kappa 系数一致！;
            %let kappa_type = #SIMPLE;
        %end;
    %end;


    /*7. 行列变量补齐分类，添加频数变量*/
    proc sql noprint;
        /*找到未被使用的变量名 FREQ&i*/
        %let IS_TEMP_FREQ_VAR_EXIST = TRUE;
        %let i = 1;
        %do %until(&IS_TEMP_FREQ_VAR_EXIST = FALSE);
            select * from DICTIONARY.COLUMNS where libname = "WORK" and memname = "TEMP_INDATA" and upcase(name) = "FREQ&i";
            %if &SQLOBS = 0 %then %do;
                %let IS_TEMP_FREQ_VAR_EXIST = FALSE;
            %end;
            %else %do;
                %let i = %eval(&i + 1);
            %end;
        %end;
        %let temp_freq_var = FREQ&i;

        /*找到未被使用的变量名 ROWN&i*/
        %let IS_TEMP_ROWN_VAR_EXIST = TRUE;
        %let i = 1;
        %do %until(&IS_TEMP_ROWN_VAR_EXIST = FALSE);
            select * from DICTIONARY.COLUMNS where libname = "WORK" and memname = "TEMP_INDATA" and upcase(name) = "ROWN&i";
            %if &SQLOBS = 0 %then %do;
                %let IS_TEMP_ROWN_VAR_EXIST = FALSE;
            %end;
            %else %do;
                %let i = %eval(&i + 1);
            %end;
        %end;
        %let temp_rown_var = ROWN&i;

        /*找到未被使用的变量名 COLN&i*/
        %let IS_TEMP_COLN_VAR_EXIST = TRUE;
        %let i = 1;
        %do %until(&IS_TEMP_COLN_VAR_EXIST = FALSE);
            select * from DICTIONARY.COLUMNS where libname = "WORK" and memname = "TEMP_INDATA" and upcase(name) = "COLN&i";
            %if &SQLOBS = 0 %then %do;
                %let IS_TEMP_COLN_VAR_EXIST = FALSE;
            %end;
            %else %do;
                %let i = %eval(&i + 1);
            %end;
        %end;
        %let temp_coln_var = COLN&i;

        /*添加若干行权重为0的观测*/
        create table temp_indata_add_level_freq as
            select
                &table_row_var,
                &table_col_var,
                %if &weight = #NULL %then %do;
                    1
                %end;
                %else %do;
                    &weight
                %end; as &temp_freq_var,
                (case %do i = 1 %to &table_level_n;
                          when &table_row_var = "&&table_level_&i" then &i
                      %end;
                end) as &temp_rown_var,
                (case %do i = 1 %to &table_level_n;
                          when &table_col_var = "&&table_level_&i" then &i
                      %end;
                end) as &temp_coln_var
            from temp_indata
            outer union corr
            select
                 var as &table_row_var,
                 var as &table_col_var,
                 0   as &temp_freq_var,
                 monotonic() as &temp_rown_var,
                 monotonic() as &temp_coln_var
             from temp_distinct_var
            ;
    quit;
    

    /*8. 计算 Kappa 系数假设检验的 P 值*/
    proc freq data = temp_indata_add_level_freq noprint;
        tables &temp_rown_var*&temp_coln_var /%if &kappa_type = #SIMPLE %then %do;
                                                  %if &exact = FALSE %then %do;
                                                      agree(nullkappa = &null_kappa)
                                                  %end;
                                                  %else %do;
                                                      agree
                                                  %end;
                                              %end;
                                              %else %do;
                                                  %if &exact = FALSE %then %do;
                                                      agree(wt = &kappa_weight nullwtkappa = &null_kappa)
                                                  %end;
                                                  %else %do;
                                                      agree(wt = &kappa_weight)
                                                  %end;
                                              %end;
                                              norow nocol nopercent;
        %if &exact = TRUE %then %do;
            exact
        %end;
        %else %do;
            test
        %end;
        %if &kappa_type = #WEIGHTED %then %do;
            wtkappa
        %end;
        %else %do;
            kappa
        %end;
        ;
        weight &temp_freq_var /zeros;
        output out = temp_out_kappa agree;
    run;


    /*9. 提取 Kappa 系数假设检验的 P 值*/
    proc sql noprint;
        select * from DICTIONARY.TABLES where libname = "WORK" and memname = "TEMP_OUT_KAPPA";
        %if &SQLOBS = 0 %then %do;
            %let kappap = %superq(placeholder);
        %end;
        %else %do;
            /*获取 Kappa 系数*/
            %if &kappa_type = #SIMPLE %then %do;
                select _KAPPA_ format = &format into :KAPPA from temp_out_kappa;
            %end;
            %else %do;
                select _WTKAP_ format = &format into :KAPPA from temp_out_kappa;
            %end;

            %if &KAPPA = %bquote(.) %then %do;
                %put NOTE: 表过于稀疏，未对 Kappa 系数进行检验！;
                %let kappap = %superq(placeholder);
            %end;
            %else %do;
                /*在参数 SIDES = 1 的情况下，比较样本 Kappa 系数与零假设的 Kappa 系数，决定进行左侧或右侧检验*/
                %if &sides = 1 %then %do;
                    %if %sysevalf(&KAPPA <= &null_kappa) %then %do;
                        %let test_side = L;
                    %end;
                    %else %do;
                        %let test_side = R;
                    %end;
                %end;
                /*在参数 SIDES = 2 的情况下，进行双侧检验*/
                %else %do;
                    %let test_side = 2;
                %end;

                /*对简单 or 加权 Kappa 系数进行检验*/
                %if &kappa_type = #SIMPLE %then %do;
                    %let kappa_method = KAPPA;
                %end;
                %else %do;
                    %let kappa_method = WTKAP;
                %end;

                /*是否进行精确检验*/
                %if &exact = FALSE %then %do;
                    %let test_type = %bquote();
                %end;
                %else %do;
                    %let test_type = X;
                %end;

                /*Kappa P 值的变量名*/
                %let kappap_var = %substr(&test_type.P&test_side._&kappa_method, 1, 8);
                
                select &kappap_var format = &format into :KAPPAP from temp_out_kappa;
            %end;
        %end;
    quit;


    /*10. 构建输出数据集*/
    %temp_out:
    proc sql noprint;
        create table temp_out (item char(200), value char(200));
        insert into temp_out values("&stat_note", "&kappap");
    quit;
    

    /*11. 输出数据集*/
    data &libname_out..&memname_out(%if %superq(dataset_options_out) = %bquote() %then %do;
                                        keep = item value
                                    %end;
                                    %else %do;
                                        &dataset_options_out
                                    %end;);
        set temp_out;
    run;

    /*----------------------------------------------运行后处理----------------------------------------------*/
    /*删除中间数据集*/
    %exit_with_tempdata_created:
    %if %superq(del_temp_data) = TRUE %then %do;
        proc datasets noprint nowarn;
            delete temp_indata
                   temp_indata_add_level_freq
                   temp_distinct_row_var
                   temp_distinct_col_var
                   temp_distinct_var
                   temp_out_kappa
                   temp_out
                   ;
        quit;
    %end;

    %exit:
    %put NOTE: 宏 KappaP 已结束运行！;
%mend;
