//+------------------------------------------------------------------+
//|                                             Ichi MULTI-SCALP.mq4 |
//|                        Copyright 2019, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
//Regular Constants
//#define LOTFACTOR 0.1 //unit lot
//#define LIQFACTOR 0.25 // our broker multiplies 0.25 to the usual maintenance margin get a measurement called liquidation margin(we will use this). 
#define SELLTICKETS 0
#define BUYTICKETS 1
//--- input parameters
extern int WAIT_BARS = 5;
extern int MAX_TRADES = 3;
extern int NEW_TRADE_WAIT_BARS = 26;
extern int MULTIPLIER_TP = 5;
extern int MULTIPLIER_SL = 3;
extern bool Martingale = True;
extern bool Time_Based_Orders = True;
extern bool Do_Separation = True;
extern int ATR_period = 20;
extern int ATR_avg_period = 5;
//extern int Aroon_period = 14;
extern int Slippage = 3; 
extern double ADX_period = 14;
extern double ADX_avg_period = 5;
extern double EA_tot_risk = 0.15;
//extern double risk_wiggle_room = 0.05;
extern double pseudo_sl = 20;
//revelant arrays
double atr_data [];
double adx_data [];
int AllTickets [2][3];
//relevant variables;
double Target;
double aroon_up;
double aroon_down;
double current_time_span_A;
double current_time_span_B;
double current_time_lagging_span;
double conversion_line;
double base_line;
double lagged_price_under;
double lagged_price_above;
double close_price;
double current_time_span_A_lag;
double current_time_span_B_lag;
double forward_time_span_A;
double forward_time_span_B; 
double atr;
double atr_avg;
double adx; 
double adx_avg;
double pos_di;
double neg_di;
double trailing_stop;
double take_profit;
double UsePoint;
double UseSlippage;
double margin_required;
double lots;
double Value_Per_Pip;
int current_index = 0;
int CHECK_STEP = 1;
int TIME_GAP = 27;
int TIME_GAP_LAG = 53;
int id = 100;
int Current_BuyTicket = 0;
int Current_SellTicket = 0;
int timeframe = PERIOD_CURRENT;
int max_trades_open = 0;
#define SizeOfArrays 31
//start-up functions
// Pip Point Function
double PipPoint(string Currency){	
	int CalcDigits = MarketInfo(Currency,MODE_DIGITS);
	double CalcPoint = 0;
	if(CalcDigits == 2 || CalcDigits == 3) {
	   CalcPoint = 0.01;
	}
	else if(CalcDigits == 4 || CalcDigits == 5) {
	   CalcPoint = 0.0001;
	}
	return(CalcPoint);
}

//Get Slippage Function
int GetSlippage(string Currency, int SlippagePips){
	int CalcDigits = MarketInfo(Currency,MODE_DIGITS);
	double CalcSlippage = 0;
	if(CalcDigits == 2 || CalcDigits == 4) {
	   CalcSlippage = SlippagePips;
	}
	else if(CalcDigits == 3 || CalcDigits == 5) {
	   CalcSlippage = SlippagePips * 10;
	}
	return(CalcSlippage);
}
/*
double ValueFinder(){
   string base_currency = StringSubstr(Symbol(),3, 3);
	string quote_currency = StringSubstr(Symbol(), 0, 3);
	double value = 1.0;
	if (base_currency == "CAD")
	{
		return value;
	}
	else if (quote_currency == "CAD")
	{
		value = 1/Ask;
		return value;
	}
	else
	{ 
		string base_ex = StringConcatenate(base_currency, "CAD");
		double ask = MarketInfo(base_ex, MODE_ASK);
		if (GetLastError() == 4106){
			base_ex = StringConcatenate("CAD", base_currency);
			double bid = MarketInfo(base_ex, MODE_BID);
			value = bid;
			return value;
		}
		value = 1/ask;
	}
	return value;
}
*/
double ValueFinder(){
   return 1.00;
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   UsePoint = PipPoint(Symbol());
	UseSlippage = GetSlippage(Symbol(), Slippage);
	Value_Per_Pip = ValueFinder();
	ArrayResize(adx_data, SizeOfArrays);
	ArraySetAsSeries(adx_data, True);
	ArrayResize(atr_data, SizeOfArrays);
	ArraySetAsSeries(atr_data, True);
	margin_required = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Print(max_trades_open);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
      //close price of the prev. bar
      close_price = iClose(Symbol(), timeframe, CHECK_STEP);
      //ATR data
      atr = iATR(Symbol(), timeframe, ATR_period, CHECK_STEP);
      collect_atr_data();
      //ADX data
      adx = iADX(Symbol(), timeframe, ADX_period, PRICE_CLOSE, MODE_MAIN, CHECK_STEP);
      pos_di = iADX(Symbol(), timeframe, ADX_period, PRICE_CLOSE, MODE_PLUSDI, CHECK_STEP);
      neg_di = iADX(Symbol(), timeframe, ADX_period, PRICE_CLOSE, MODE_MINUSDI, CHECK_STEP);
      collect_adx_data();
      if(!Order_Found() && Seperated()){
         if(Trending_Up()){
            while(IsTradeContextBusy()){
				   Sleep(10);
				}
				Calc_Lot();
				Make_Tp(OP_BUY);
				pick_trailing_stop(OP_BUY);
				Current_BuyTicket = OrderSend(Symbol(), OP_BUY, lots, Ask, UseSlippage, trailing_stop, take_profit, "Buy Order", id, 0, Green);
				if(Current_BuyTicket > 0){
				   Current_SellTicket = 0;
				}
				AllTickets[BUYTICKETS][current_index] = Current_BuyTicket;
				current_index = current_index + 1;
         }
         else if(Trending_Down()){
            while(IsTradeContextBusy()){
				   Sleep(10);
				}
				Calc_Lot();
				Make_Tp(OP_SELL);
				pick_trailing_stop(OP_SELL);
				Current_SellTicket = OrderSend(Symbol(), OP_SELL, lots, Bid, UseSlippage, trailing_stop, take_profit, "Sell Order", id, 0, Red);
				if(Current_SellTicket > 0){
				   Current_BuyTicket = 0;
				}
				AllTickets[SELLTICKETS][current_index] = Current_SellTicket;
				current_index = current_index + 1;
         }
      }
      else if(Current_SellTicket > 0){
         pick_trailing_stop(OP_SELL);
         OrderSelect(Current_SellTicket, SELECT_BY_TICKET);
         if(Exit_Order(OP_SELL)){
            Clean_Orders(OP_SELL);
         }
         else if(trailing_stop < OrderStopLoss()){
            Modify_Stops(OP_SELL);
         }
         else{
            if(current_index < MAX_TRADES && (Loss_Reacher(OP_SELL))){
               Add_Order(OP_SELL);
            }
         }
      }
      else if(Current_BuyTicket > 0){
         pick_trailing_stop(OP_BUY);
         OrderSelect(Current_BuyTicket, SELECT_BY_TICKET);
         if(Exit_Order(OP_BUY)){
            Clean_Orders(OP_BUY);
         }
         else if(trailing_stop > OrderStopLoss()){
            Modify_Stops(OP_BUY);
         }
         else{
            if(current_index < MAX_TRADES && (Loss_Reacher(OP_BUY))){
               Add_Order(OP_BUY);
            }
         }
         
      }
  }
//+------------------------------------------------------------------+
bool Order_Found(){
   if(Current_BuyTicket > 0 && OrderSelect(Current_BuyTicket, SELECT_BY_TICKET) && OrderCloseTime() == 0){
      Current_SellTicket = 0;
      return True;
   }
   else if(Current_SellTicket > 0 && OrderSelect(Current_SellTicket, SELECT_BY_TICKET) && OrderCloseTime() == 0){
      Current_BuyTicket = 0;
      return True;
   }
   if(current_index != 0){
      Current_BuyTicket = 0;
      Current_SellTicket = 0;
      current_index = 0;
   }
   return False;
}
//Finds the optimal lot for our risk tolerance.
void Calc_Lot(){
   double equity = AccountEquity();
   double part_one_alg = equity - (equity*(1 - EA_tot_risk));//alg = algebra
   double part_two_alg = 1;
   if(Martingale){
      part_two_alg = margin_required*MAX_TRADES;
   }
   else{
      part_two_alg = margin_required;
   }
   lots = part_one_alg/part_two_alg; 
   lots = NormalizeDouble(lots, 2); //lots is interpreted up to the second decimal point. 
}
/*
bool RISK_TEST(int order_type){
   Calc_Lot();
   double potential_loss; 
   double potential_usbl_margin_percent;
   if(order_type == OP_BUY){
      pick_trailing_stop(OP_BUY);
      potential_loss = ((Ask - trailing_stop)*(lots*Value_Per_Pip)/(UsePoint*LOTFACTOR));
      potential_usbl_margin_percent = (AccountFreeMargin() - potential_loss - (margin_required*lots))/(AccountEquity() - potential_loss);
      return potential_usbl_margin_percent > 1 - EA_tot_risk - risk_wiggle_room;
   }
   else if(order_type == OP_SELL){
      pick_trailing_stop(OP_SELL);      
      potential_loss = ((trailing_stop - Bid)*(lots*Value_Per_Pip)/(UsePoint*LOTFACTOR));
      potential_usbl_margin_percent = (AccountFreeMargin() - potential_loss - (margin_required*lots))/(AccountEquity() - potential_loss);
      return potential_usbl_margin_percent > 1 - EA_tot_risk - risk_wiggle_room;
   }
   return False;
}
*/
bool Time_For_New_Trade(int order_type){
   if(!Time_Based_Orders){
      return False;
   }
   if(order_type == OP_BUY){
      OrderSelect(Current_BuyTicket, SELECT_BY_TICKET);
      return iBarShift(Symbol(), timeframe, OrderOpenTime(), True) >= NEW_TRADE_WAIT_BARS && Bullish();
   }
   else if(order_type == OP_SELL){
      OrderSelect(Current_SellTicket, SELECT_BY_TICKET);
      return iBarShift(Symbol(), timeframe, OrderOpenTime(), True) >= NEW_TRADE_WAIT_BARS && Bearish();
   }
   return False;
}
bool Loss_Reacher(int order_type){
   if(!Martingale){
      return False;
   }
   double pip_distance;
   if(order_type == OP_BUY){
      OrderSelect(Current_BuyTicket, SELECT_BY_TICKET);  
      pip_distance = (Bid - OrderOpenPrice())/UsePoint;
      return pip_distance <= -pseudo_sl && OrderCloseTime() == 0;
   }
   else if(order_type == OP_SELL){
      OrderSelect(Current_SellTicket, SELECT_BY_TICKET);
      pip_distance = (OrderOpenPrice() - Ask)/UsePoint;
      return pip_distance <= -pseudo_sl && OrderCloseTime() == 0;
   }
   return False;
}
void Clean_Orders(int order_type){
   int index = 2;
   if(order_type == OP_SELL){
      index = SELLTICKETS;
   }
   else if(order_type == OP_BUY){
      index = BUYTICKETS;
   }
   else{
      return;
   }
   int current_ticket;
   for(int i = 0; i < MAX_TRADES; i++){
      current_ticket = AllTickets[index][i];
      if(current_ticket <= 0){
         break;
      }
      OrderSelect(current_ticket, SELECT_BY_TICKET);
      if(OrderCloseTime() == 0){
         while(OrderCloseTime() == 0){
            while(IsTradeContextBusy()){
               Sleep(10);
            }
            if(index == SELLTICKETS){
               if(OrderClose(current_ticket, lots, Ask, UseSlippage, Red)){
                  Current_SellTicket = 0;
                  AllTickets[index][i] = 0;
               }
            }
            else{
               if(OrderClose(current_ticket, lots, Bid, UseSlippage, Green)){
                  Current_BuyTicket = 0;
                  AllTickets[index][i] = 0;
               }
            }
            OrderSelect(current_ticket, SELECT_BY_TICKET);
         }
      }
   }
   current_index = 0;
}
void Add_Order(int order_type){
   if(order_type == OP_SELL){
      while(IsTradeContextBusy()){
         Sleep(10);
      }
      Make_Tp(OP_SELL);
      pick_trailing_stop(OP_SELL);
      Current_SellTicket = OrderSend(Symbol(), OP_SELL, lots, Bid, UseSlippage, trailing_stop, take_profit, "Sell Order", id, 0, Red);
      if(Current_SellTicket > 0){
         AllTickets[SELLTICKETS][current_index] = Current_SellTicket;
         current_index = current_index + 1;
         if(max_trades_open < current_index){
            max_trades_open = current_index;
         }
      }
   }
   else if(order_type == OP_BUY){
      while(IsTradeContextBusy()){
         Sleep(10);
      }
      pick_trailing_stop(OP_BUY);
      Make_Tp(OP_BUY);
      Current_BuyTicket = OrderSend(Symbol(), OP_BUY, lots, Ask, UseSlippage, trailing_stop, take_profit, "Buy Order", id, 0, Green);
      if(Current_BuyTicket > 0){
         AllTickets[BUYTICKETS][current_index] = Current_BuyTicket;
         current_index = current_index + 1;
         if(max_trades_open < current_index){
            max_trades_open = current_index;
         }
      }
   }
   else{
      return;
   }
}
void Modify_Stops(int order_type){
   int index = 2;
   if(order_type == OP_SELL){
      index = SELLTICKETS;
   }
   else if(order_type == OP_BUY){
      index = BUYTICKETS;
   }
   else{
      return;
   }
   int current_ticket;
   for(int i = 0; i < MAX_TRADES; i++){
      current_ticket = AllTickets[index][i];
      if(current_ticket <= 0){
         continue;
      }
      OrderSelect(current_ticket, SELECT_BY_TICKET);
      OrderModify(current_ticket, OrderOpenPrice(), trailing_stop, OrderTakeProfit(), OrderExpiration());
   }
}
bool Seperated(){
   int ticket = 0;
   if(Current_SellTicket <= 0 && Current_BuyTicket <= 0){
      return True;
   }
   else if(Current_SellTicket > 0){
      ticket = Current_SellTicket;
   }
   else if(Current_BuyTicket > 0){
      ticket = Current_BuyTicket;
   }
   if(Do_Separation && OrderSelect(ticket, SELECT_BY_TICKET)){
      return OrderCloseTime() > 0 && !(iBarShift(Symbol(), timeframe, OrderCloseTime()) < WAIT_BARS);
   }
   return True;
}
void collect_adx_data(){
   for(int i = 0; i < ADX_avg_period + 1; i++){
      adx_data[i] = iADX(Symbol(), timeframe, 14, PRICE_CLOSE, MODE_MAIN, i + CHECK_STEP);
   }
}
void collect_atr_data(){
   for(int i = 0; i < ATR_avg_period + 1; i++){
      adx_data[i] = iADX(Symbol(), timeframe, 14, PRICE_CLOSE, MODE_MAIN, i + CHECK_STEP);
   }
}
bool Forecast_Long(){
   return forward_time_span_A > forward_time_span_B;
}
bool Forecast_Short(){
   return forward_time_span_A < forward_time_span_B;
}
bool Lag_above(){
   if(current_time_span_A_lag > current_time_span_B_lag){
      return current_time_lagging_span > current_time_span_A_lag && current_time_lagging_span > lagged_price_above;
   }
   else{
      return current_time_lagging_span > current_time_span_B_lag && current_time_lagging_span > lagged_price_above;   
  } 
}
bool Lag_below(){
   if(current_time_span_A_lag < current_time_span_B_lag){
      return current_time_lagging_span < current_time_span_A_lag && current_time_lagging_span < lagged_price_under;
   }
   else{
      return current_time_lagging_span < current_time_span_B_lag && current_time_lagging_span < lagged_price_under;   
  }
}
bool Trending_Up(){
   return adx >= 26 && adx > adx_avg + 1 && pos_di > neg_di;
}
bool Trending_Down(){
   return adx >= 26 && adx > adx_avg + 1 && pos_di < neg_di;
}
bool Reaching_New_Highs(){
   return aroon_up > aroon_down && aroon_up > 70;
}
bool Reaching_New_Lows(){
   return aroon_down > aroon_up && aroon_down > 70;
}
bool Bullish(){
   double higher = current_time_span_A;
   if(current_time_span_A < current_time_span_B){
      higher = current_time_span_B;
   }
   if(close_price > higher && Forecast_Long() && conversion_line >= base_line && close_price > base_line && conversion_line > higher){
      return Trending_Up() && Reaching_New_Highs() && Lag_above();
   }
   return False;
}
bool Bearish(){
   double lower = current_time_span_A;
   if(current_time_span_A > current_time_span_B){
      lower = current_time_span_B;
   }
   if(close_price < lower && Forecast_Short() && conversion_line <= base_line && close_price < base_line && conversion_line < lower){
      return Trending_Down() && Reaching_New_Lows() && Lag_below();
   }
   return False;
}
void pick_trailing_stop(int order_type){
   if(order_type == OP_BUY){
      trailing_stop = Bid - atr*MULTIPLIER_SL;
      return;
   }
   else if(order_type == OP_SELL){
      trailing_stop = Ask + atr*MULTIPLIER_SL;
      return;
   }
   trailing_stop = 0;
}
bool Exit_Order(int order_type){
   if(order_type == OP_BUY){
      return Trending_Down(); 
   }
   else if(order_type == OP_SELL){
      return Trending_Up();
   }
   return False;
}
/*
bool Violates_Risk_Rule(){
   return AccountFreeMargin()/AccountEquity() < 1 - EA_tot_risk + risk_wiggle_room;
}
*/
void Get_Atr_Target(){
   Target = atr*MULTIPLIER_TP;
}
void Make_Tp(int order_type){
   Get_Atr_Target();
   if(order_type == OP_BUY){
      RefreshRates();
      //take_profit = Ask + UsePoint*TARGET; 
      take_profit = Low[1] + Target;
   }
   else{
      RefreshRates();
      //take_profit = Bid - UsePoint*TARGET;
      take_profit = High[1] - Target;
   }
}