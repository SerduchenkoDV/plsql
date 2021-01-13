--1. Есть строка – номер телефона, переданный с фронта.
--   Нужно с помощью регулярного выражения удалить ВСЕ НЕЧИСЛОВЫЕ символы ЗА ИСКЛЮЧЕНИЕМ лидирующего (находящегося на первом месте в строке) «+» (символа плюс)
--   
--2. Спроектируйте структуру таблиц для ведения информации о счетах, движениях по счетам и остатках.
--   По сформированной структуре напишите запросы чтобы получить:
--	- текущий остаток по счету
--	- остаток по счету на произвольную дату
--	- дебетовый (расходный) и кредитовый (приходный) оборот по счету за произвольный период, то есть сумму списаний и поступлений на счет
--
--   Напишите функцию для расчета процентов по остаткам на счете.
--   Параметры функции:
--	· Счет
--	· Дата начала периода
--	· Дата окончания периода
--	· Процентная ставка.
--   Результат функции: сумма процентов
--
--Базовая формула для расчета процентов за период: СуммаПроцентов = ОстатокНаСчете * ПроцентнаяСтавка * ДнейВПериоде / КоличествоДнейВГоду
--Формула используется для периодов, в которых остаток на счете не менялся. Если в расчетном периоде остаток менялся, то период делится на 
--части и проценты по ним складываются. В качестве остатка для расчета процентов используется входящий остаток по счету на начало дня. 
--То есть если в течение дня остаток по счету менялся, то для расчета процентов за этот день используется остаток, который был на счете до сегодняшних движений.
 


select REGEXP_REPLACE(
		REGEXP_REPLACE( 
	  		REGEXP_REPLACE('вавS++ва+7(па92)2-4ва1  42++++sae0.7+3ss+', '[^\+[:digit:]]')   -- убираем все символы кроме цифр и +
	              	,'\+{1,}', '+')															-- убираем многократные повторения +
		    ,'([[:digit:]])(\+)','\1') 														-- убираем все + ПОСЛЕ цифр 
from dual;	  

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Базу не создавал и функцию не компилировал (все писалось сразу в редакторе), в отличие от задачки с регулярными выражениями. Должно работать, но могут быть ошибки по синтаксису. 
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
create table Bank_account (			-- основная информация по счетам
account_id NUMBER,					-- внутренний id счета в системе
account_num NUMBER,					-- полный номер банковского счета 
acocunt_activity NUMBER(1),			-- активен/заблокирован (1/0)
account_type_id NUMBER,  			-- тип счета (например: накопительный/дебетовый/кредитный/сберегательный и т.п. Можно так же сегмент пользователей указывать вип/масс)
create_date DATE,					-- дата открытия счета
block_date DATE,					-- дата закрытия/блокировки счета
CONSTRAINT pk_bank_account PRIMARY KEY (account_id)
);

create table Account_type (			-- основная информация по типам счетов
a_type_id NUMBER,					-- id типа
a_type_name VARCHAR2 (50),			-- наименование типа 
a_type_activity NUMBER(1),			-- активен/закрыт (можно конечно смотреть на дату закрытия, но в выборках так быстрее будет)
param_id NUMBER,  					-- id набора параметров по типу
create_date DATE,					-- дата создания типа			
close_date DATE,					-- дата закрытия типа (при смене параметров, для историчности лучше закрывать и создавать новый с новой привязкой) 
CONSTRAINT pk_account_type PRIMARY KEY (a_type_id),
CONSTRAINT fk_a_type_param 
FOREIGN KEY (param_id) 
REFERENCES A_type_param (param_id)

);

create table A_type_param (			-- информация по расчетным параметрам типов счетов (процентные ставки на остаток/кешбек/кредит, лимиты, стоимость обсдуживания и т.п.)
param_id NUMBER,					-- id набора параметров
percent_amount NUMBER,  			-- в нашем случае, только процент на остаток в формате десятичного числа (6,5% будет сидеть как 0,065)
CONSTRAINT pk_a_type_param PRIMARY KEY (param_id)
);

create table Bank_account_calc (	-- основная информация по операциям на счете
account_id NUMBER,					-- внутренний id счета в системе
operation_amount NUMBER,			-- сумма операции 
operation_date DATE,				-- дата операции
calc_type NUMBER,					-- дебет/кредит (-1/1)
CONSTRAINT fk_bank_account_c
FOREIGN KEY (account_id) 
REFERENCES Bank_account (account_id)
);

-- Остаток по счету (и любые текушие показатели, которые отображаются в мобильном/онлайн-банкинге) я бы для удобства вынес представление. 

CREATE VIEW Bank_account_info AS										
SELECT 	bac.account_id as account_id, 
		sum(bac.calc_type * operation_amount) as account_balance		-- суммируем все произведенные операции с группировкой по id счета
FROM 	Bank_account_calc bac, Bank_account ba 
WHERE 	ba.account_id = bac.account_id
AND   	ba.acocunt_activity = 1											-- берем только активные счета, т.к. счет с ненулевым балансом не закроют
GROUP BY bac.account_id
WITH READ ONLY;															-- защита от случайного изменения данных через представление


--ЗАПРОСЫ ПО ЗАДАНИЮ

-- текущий остаток по счету
select account_balance from Bank_account_info where account_id = 1377731;

-- остаток по счету на произвольную дату

SELECT 	sum(bac.calc_type * operation_amount) as account_balance		
FROM 	Bank_account_calc bac, Bank_account ba 
WHERE 	ba.account_id = bac.account_id
--AND   	ba.acocunt_activity = 1									-- проверка на активность счета не нужна тут, так как запрос не массовый + историчные данные
AND   	bac.account_id = 1377731
AND 	bac.operation_date	<	date '2018-12-31'					-- timestamp '2018-12-31 12:31:02' если нужно по времени проверить, date - это начало суток 0:00			
GROUP BY bac.account_id;


-- дебетовый (расходный) и кредитовый (приходный) оборот по счету за произвольный период, то есть сумму списаний и поступлений на счет
SELECT 	bac.account_id,
		sum(bac.calc_type * operation_amount) as account_balance,
		DECODE( bac.calc_type, -1, 'account_debet_balance',
								1, 'account_credit_balance') calculation_type,
FROM 	Bank_account_calc bac, Bank_account ba 
WHERE 	ba.account_id = bac.account_id
AND   	bac.account_id = 1377731
AND 	bac.operation_date	BETWEEN	date '2018-12-31' 
								AND date '2020-12-31'							
GROUP BY bac.account_id, bac.calc_type;

-- Напишите функцию для расчета процентов по остаткам на счете.
--Параметры функции:
--        Счет
--        Дата начала периода
--        Дата окончания периода
--        Процентная ставка.

-- Результат функции: сумма процентов
-- Базовая формула для расчета процентов за период: СуммаПроцентов = ОстатокНаСчете * ПроцентнаяСтавка * ДнейВПериоде / КоличествоДнейВГоду
-- Формула используется для периодов, в которых остаток на счете не менялся. Если в расчетном периоде остаток менялся, то период делится на части 
-- и проценты по ним складываются. В качестве остатка для расчета процентов используется входящий остаток по счету на начало дня. 
-- То есть если в течение дня остаток по счету менялся, то для расчета процентов за этот день используется остаток, который был на счете до сегодняшних движений.

CREATE OR REPLACE FUNCTION PersentCalculation
   ( V_account_id 	  IN NUMBER,
	 V_date_from 	  IN DATE,
	 V_date_to 		  IN DATE,
	 V_percent_amount IN NUMBER
   )
   RETURN NUMBER
IS
  Per_Calc NUMBER;
  Per_Calc_result NUMBER;
  create_dt DATE;
  block_dt DATE;
  
  cursor get_period_dates is
  select V_date_from + level - 1  as date_calculation, 																	-- Готовим выборку всех дней, попавших в искомый период.
		 1 / (add_months(trunc(V_date_from + level - 1,'yyyy'),12)-trunc(V_date_from + level - 1,'yyyy')) as date_coef 	-- Для каждого дня в искомом периоде высчитываем отношение этого дня 
   from dual 																											-- к количеству дней в году, в котором этот день существует.
   connect by level < TRUNC(to_date (V_date_to, 'yyyy/mm/dd')) - TRUNC(to_date (V_date_from, 'yyyy/mm/dd')) + 1;		-- Таким образом обрабатывается любой период, включая многолетний

   date_calc get_period_dates.date_calculation%ROWTYPE;
   date_cof get_period_dates.date_coef%ROWTYPE;
 
BEGIN

SELECT 	create_date, block_date													-- Запрашиваем период активности счета.				
INTO   	create_dt, block_dt
FROM 	Bank_account
WHERE 	account_id = V_account_id;
 
IF (V_date_from < create_dt) THEN V_date_from := create_dt;   					-- Отсекаем начисление процентов за дни, попавшие в искомый период,
IF (V_date_to > block_dt AND block_dt IS NOT NULL ) THEN V_date_to = block_dt;	-- но выходящие за рамками срока существования и активности счета.

Per_Calc_result := 0;

OPEN get_period_dates;
 LOOP
 EXIT WHEN get_period_dates%NOTFOUND;

 FETCH get_period_dates INTO date_calc, date_cof;								-- Считываем построчно, по одному дни и коэффициенты для расчетов из этих дней 
 
	SELECT 	sum(bac.calc_type * operation_amount) as account_balance			-- Расчитываем остаток на счете на каждый день из искомого диапазона и заносим в переменную
	INTO Per_Calc
	FROM 	Bank_account_calc bac, Bank_account ba 
	WHERE 	ba.account_id = bac.account_id
	AND   	bac.account_id = V_account_id
	AND 	bac.operation_date	<	date_calc									-- Так как остаток по условию это остаток на закрытие прошлого дня, то строго "<"
	GROUP BY bac.account_id;
	
	Per_Calc := Per_Calc * V_percent_amount * date_cof;							-- Высчитываем сумму процентов за каждый день из искомого диапазона.
																				-- Тут можно было бы не использовать передаваемый процент, в брать исторические 
																				-- данные из связки Account_type - A_type_param и расчитать проценты, с учетом изменения ставок.  
	 
	Per_Calc_result := Per_Calc_result + Per_Calc; 								-- Накапливаем итоговую сумму процентов			
 
 END LOOP;
CLOSE get_period_dates;
RETURN Per_Calc_result;   
END PersentCalculation;

   
  


