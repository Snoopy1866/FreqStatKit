/*
===================================
Macro Name: FreqStatKit
Macro Label: 频数统计工具包
Author: wtwang
Version Date: 2023-02-14 V1.0
===================================
*/

%macro FreqStatKit(CALL) /des = "频数统计工具包" parmbuff;
/*
CALL:          调用的宏名称
... :          传递给宏的参数
*/

    /*打开帮助文档*/
    %if %qupcase(%superq(SYSPBUFF)) = %bquote((HELP)) or %qupcase(%superq(SYSPBUFF)) = %bquote(()) %then %do;
        /*
        %let host = %bquote(192.168.0.199);
        %let help = %bquote(\\&host\统计部\SAS宏\08 FreqStatKit\05 帮助文档\readme.html);
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
        X explorer "https://github.com/Snoopy1866/FreqStatKit/tree/main";
        %goto exit;
    %end;

    /*----------------------------------------------初始化----------------------------------------------*/
    /*统一参数大小写*/
    %let call               = %upcase(%sysfunc(strip(%bquote(&call))));


    /*----------------------------------------------参数检查----------------------------------------------*/
    /*CALL*/
    %if %superq(call) = %bquote() %then %do;
        %put ERROR: 参数 CALL 为空！;
        %goto exit;
    %end;

    %let support_call_expr = %bquote(/^(BINOMIALCI|KAPPACI|KAPPAP)$/); /*受支持的宏名称*/
    %let support_call_id = %sysfunc(prxparse(&support_call_expr));
    %if %sysfunc(prxmatch(&support_call_id, %superq(call))) = 0 %then %do;
        %put ERROR: 宏 %superq(call) 暂不受支持！;
        %goto exit;
    %end;
    %else %do;
        proc sql noprint;
            select * from DICTIONARY.CATALOGS where libname = "WORK" and memname = "SASMACR" and objname = "&call";
        quit;
        %if &SQLOBS = 0 %then %do;
            %put ERROR: 宏 %bquote(&call) 未载入，请载入宏程序后再次运行！;
            %goto exit;
        %end;
    %end;

    /*----------------------------------------------主程序----------------------------------------------*/
    %put NOTE: 调用宏 %nrbquote(%)%bquote(&call&SYSPBUFF);
    %&call&SYSPBUFF;
    

    /*----------------------------------------------运行后处理----------------------------------------------*/
    %exit:
    /*删除中间数据集*/
    proc datasets noprint nowarn;
        delete temp_sasmacro_list
               ;
    quit;

    %put NOTE: 宏 FreqStatKit 已结束运行！;
%mend;
