/*
===================================
Macro Name: FreqStatKit
Macro Label: Ƶ��ͳ�ƹ��߰�
Author: wtwang
Version Date: 2023-02-14 V1.0
===================================
*/

%macro FreqStatKit(CALL) /des = "Ƶ��ͳ�ƹ��߰�" parmbuff;
/*
CALL:          ���õĺ�����
... :          ���ݸ���Ĳ���
*/

    /*�򿪰����ĵ�*/
    %if %qupcase(%superq(SYSPBUFF)) = %bquote((HELP)) or %qupcase(%superq(SYSPBUFF)) = %bquote(()) %then %do;
        /*
        %let host = %bquote(192.168.0.199);
        %let help = %bquote(\\&host\ͳ�Ʋ�\SAS��\08 FreqStatKit\05 �����ĵ�\readme.html);
        %if %sysfunc(system(ping &host -n 1 -w 10)) = 0 %then %do;
            %if %sysfunc(fileexist("&help")) %then %do;
                X explorer "&help";
            %end;
            %else %do;
                X mshta vbscript:msgbox("�����ĵ�������, Ŀ���ļ������ѱ��ƶ���ɾ����Orz",48,"��ʾ")(window.close);
            %end;
        %end;
        %else %do;
                X mshta vbscript:msgbox("�����ĵ�������, ��Ϊ�޷����ӵ��������� Orz",48,"��ʾ")(window.close);
        %end;
        */
        X explorer "https://github.com/Snoopy1866/FreqStatKit/tree/main";
        %goto exit;
    %end;

    /*----------------------------------------------��ʼ��----------------------------------------------*/
    /*ͳһ������Сд*/
    %let call               = %upcase(%sysfunc(strip(%bquote(&call))));


    /*----------------------------------------------�������----------------------------------------------*/
    /*CALL*/
    %if %superq(call) = %bquote() %then %do;
        %put ERROR: ���� CALL Ϊ�գ�;
        %goto exit;
    %end;

    %let support_call_expr = %bquote(/^(BINOMIALCI|KAPPACI|KAPPAP)$/); /*��֧�ֵĺ�����*/
    %let support_call_id = %sysfunc(prxparse(&support_call_expr));
    %if %sysfunc(prxmatch(&support_call_id, %superq(call))) = 0 %then %do;
        %put ERROR: �� %superq(call) �ݲ���֧�֣�;
        %goto exit;
    %end;
    %else %do;
        proc sql noprint;
            select * from DICTIONARY.CATALOGS where libname = "WORK" and memname = "SASMACR" and objname = "&call";
        quit;
        %if &SQLOBS = 0 %then %do;
            %put ERROR: �� %bquote(&call) δ���룬������������ٴ����У�;
            %goto exit;
        %end;
    %end;

    /*----------------------------------------------������----------------------------------------------*/
    %put NOTE: ���ú� %nrbquote(%)%bquote(&call&SYSPBUFF);
    %&call&SYSPBUFF;
    

    /*----------------------------------------------���к���----------------------------------------------*/
    %exit:
    /*ɾ���м����ݼ�*/
    proc datasets noprint nowarn;
        delete temp_sasmacro_list
               ;
    quit;

    %put NOTE: �� FreqStatKit �ѽ������У�;
%mend;
