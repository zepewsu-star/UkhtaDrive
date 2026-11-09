package ru.parma.invest.client;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import org.json.JSONArray;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.CookieHandler;
import java.net.CookieManager;
import java.net.CookiePolicy;
import java.net.HttpURLConnection;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Native read-only client for the existing password-protected PARMA INVEST API. */
public class MainActivity extends Activity {
    private static final String BASE = "https://invest.snt-parma.ru/panel/";
    private static final int BG = Color.rgb(18,25,34);
    private static final int PANEL = Color.rgb(29,39,50);
    private static final int GOLD = Color.rgb(215,177,111);
    private static final int WHITE = Color.rgb(239,243,247);
    private static final int MUTED = Color.rgb(168,182,194);
    private static final int GREEN = Color.rgb(139,204,164);
    private final CookieManager cookies = new CookieManager(null,CookiePolicy.ACCEPT_ORIGINAL_SERVER);
    private LinearLayout root, content, tabs;
    private TextView notice;
    private EditText password;
    private Button loginButton;
    private JSONObject summary, analyst, system;
    private String activeTab="home";
    private boolean loading=false;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        CookieHandler.setDefault(cookies);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        showLogin(null);
    }
    private int dp(int n) { return (int)(n*getResources().getDisplayMetrics().density+.5f); }
    private GradientDrawable surface(int color,int radius) {
        GradientDrawable bg=new GradientDrawable();
        bg.setColor(color); bg.setCornerRadius(dp(radius)); return bg;
    }
    private TextView text(String value,int size,int color,boolean bold) {
        TextView t=new TextView(this);
        t.setText(value); t.setTextColor(color); t.setTextSize(size);
        if(bold) t.setTypeface(Typeface.DEFAULT,Typeface.BOLD);
        t.setLineSpacing(dp(2),1f);
        return t;
    }
    private LinearLayout vertical() {
        LinearLayout l=new LinearLayout(this); l.setOrientation(LinearLayout.VERTICAL); return l;
    }
    private LinearLayout.LayoutParams margins(int bottom) {
        LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);
        lp.bottomMargin=dp(bottom); return lp;
    }
    private void add(LinearLayout parent,View view,int bottom) { parent.addView(view,margins(bottom)); }
    private void frame() {
        root=vertical(); root.setBackgroundColor(BG);
        root.setPadding(dp(18),dp(18),dp(18),dp(12));
        setContentView(root);
    }
    private Button button(String label,boolean primary) {
        Button b=new Button(this);
        b.setText(label); b.setAllCaps(false); b.setTextSize(14);
        b.setTypeface(Typeface.DEFAULT,Typeface.BOLD);
        b.setTextColor(primary?BG:WHITE);
        b.setBackground(surface(primary?GOLD:PANEL,12));
        b.setMinimumHeight(dp(52)); return b;
    }
    private void showLogin(String error) {
        loading=false; frame();
        LinearLayout header=vertical();
        header.setPadding(dp(7),dp(64),dp(7),dp(18));
        add(header,text("PI  /  PRIVATE FINANCIAL DESK",12,GOLD,true),22);
        add(header,text("PARMA INVEST",29,WHITE,true),8);
        add(header,text("Инвестиционный помощник",16,MUTED,false),8);
        root.addView(header,margins(35));
        add(root,text("Вход в аналитическую систему",18,WHITE,true),10);
        add(root,text("Используй пароль от панели invest.snt-parma.ru. Пароль не сохраняется в приложении.",14,MUTED,false),22);
        password=new EditText(this);
        password.setSingleLine(true); password.setHint("Пароль панели");
        password.setTextColor(WHITE); password.setHintTextColor(MUTED);
        password.setInputType(InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_VARIATION_PASSWORD);
        password.setPadding(dp(14),dp(12),dp(14),dp(12));
        password.setBackground(surface(PANEL,10));
        add(root,password,12);
        loginButton=button("Войти",true);
        loginButton.setOnClickListener(v->login());
        add(root,loginButton,12);
        notice=text(error==null?"Только HTTPS · реальные торговые сигналы отключены":error,
            13,error==null?MUTED:GOLD,false);
        add(root,notice,10);
    }
    private void login() {
        if(loading) return;
        final String pass=password.getText().toString();
        if(pass.length()==0) { notice.setText("Введи пароль."); return; }
        loading=true; loginButton.setEnabled(false);
        notice.setText("Соединяемся с сервером…");
        new Thread(()->{
            try {
                String html=request("GET","index.php",null);
                Matcher m=Pattern.compile("name=[\\\"']csrf[\\\"'][^>]*value=[\\\"']([^\\\"']+)[\\\"']").matcher(html);
                if(!m.find()) throw new Exception("Не удалось получить защитный токен входа.");
                String post="password="+URLEncoder.encode(pass,"UTF-8")
                    +"&csrf="+URLEncoder.encode(m.group(1),"UTF-8");
                request("POST","index.php",post);
                JSONObject first=new JSONObject(request("GET","api.php?action=summary",null));
                if(first.has("error")) throw new Exception(first.optString("error"));
                summary=first;
                analyst=new JSONObject(request("GET","api.php?action=analyst",null));
                system=new JSONObject(request("GET","api.php?action=system",null));
                runOnUiThread(()->{loading=false;dashboard();});
            } catch(Exception ex) {
                runOnUiThread(()->{
                    loading=false; loginButton.setEnabled(true);
                    notice.setText("Не удалось войти. Проверь пароль и сеть. "+ex.getMessage());
                });
            }
        }).start();
    }
    private String request(String method,String path,String body) throws Exception {
        URL url=new URL(BASE+path);
        HttpURLConnection c=(HttpURLConnection)url.openConnection();
        c.setConnectTimeout(13000); c.setReadTimeout(13000);
        c.setRequestProperty("Accept","application/json,text/html");
        c.setRequestProperty("User-Agent","ParmaInvestNative/0.9");
        c.setInstanceFollowRedirects(false); c.setRequestMethod(method);
        if("POST".equals(method)) {
            c.setDoOutput(true);
            c.setRequestProperty("Content-Type","application/x-www-form-urlencoded; charset=UTF-8");
            try(OutputStream o=c.getOutputStream()) { o.write(body.getBytes(StandardCharsets.UTF_8)); }
        }
        try {
            int status=c.getResponseCode();
            InputStream input=status>=400?c.getErrorStream():c.getInputStream();
            String data="";
            if(input!=null) {
                try(InputStream in=input;ByteArrayOutputStream buf=new ByteArrayOutputStream()) {
                    byte[] chunk=new byte[4096];int n;
                    while((n=in.read(chunk))>=0) {
                        if(n>0) buf.write(chunk,0,n);
                        if(buf.size()>1024*1024) throw new Exception("Слишком большой ответ сервера.");
                    }
                    data=buf.toString("UTF-8");
                }
            }
            if(status==401) throw new Exception("Требуется повторный вход.");
            if(status>=400) throw new Exception("HTTP "+status);
            return data;
        } finally { c.disconnect(); }
    }
    private void dashboard() {
        frame();
        LinearLayout top=new LinearLayout(this);top.setGravity(Gravity.CENTER_VERTICAL);
        TextView logo=text("PARMA  INVEST",22,WHITE,true);
        top.addView(logo,new LinearLayout.LayoutParams(0,-2,1));
        Button sync=button("↻",false);sync.setMinWidth(dp(52));
        sync.setOnClickListener(v->refresh());
        top.addView(sync,new LinearLayout.LayoutParams(dp(64),dp(48)));
        add(root,top,8);
        add(root,text("ИССЛЕДОВАТЕЛЬСКАЯ СИСТЕМА · МОСКВА",11,GOLD,true),12);
        notice=text("Данные сервера · не рекомендация к сделке",12,MUTED,false);
        add(root,notice,10);
        ScrollView sc=new ScrollView(this);sc.setFillViewport(true);
        content=vertical();content.setPadding(0,dp(6),0,dp(18));
        sc.addView(content);
        root.addView(sc,new LinearLayout.LayoutParams(-1,0,1));
        tabs=new LinearLayout(this); tabs.setGravity(Gravity.CENTER_VERTICAL);
        root.addView(tabs,new LinearLayout.LayoutParams(-1,dp(60)));
        setTab(activeTab);
    }
    private void setTab(String key) {
        activeTab=key;tabs.removeAllViews();
        String[] labels={"Обзор","Аналитика","Система"};
        String[] keys={"home","analyst","system"};
        for(int i=0;i<keys.length;i++) {
            final String next=keys[i];
            Button b=button(labels[i],key.equals(next));
            b.setTextSize(12);b.setOnClickListener(v->setTab(next));
            LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(0,dp(50),1);
            if(i>0) lp.leftMargin=dp(6);
            tabs.addView(b,lp);
        }
        content.removeAllViews();
        if("home".equals(key)) showHome();
        else if("analyst".equals(key)) showAnalyst();
        else showSystem();
    }
    private void title(String a,String b) {
        add(content,text(a,24,WHITE,true),5);
        add(content,text(b,13,MUTED,false),18);
    }
    private void card(String name,String middle,String hint) {
        LinearLayout box=vertical();
        box.setPadding(dp(17),dp(15),dp(17),dp(15));
        box.setBackground(surface(PANEL,12));
        add(box,text(name,16,WHITE,true),9);
        if(middle.length()>0) add(box,text(middle,20,GOLD,true),7);
        add(box,text(hint,12,MUTED,false),0);
        add(content,box,10);
    }
    private String str(JSONObject o,String k) {
        if(o==null||o.isNull(k)) return "—";
        String value=o.optString(k,"—");return value.length()==0?"—":value;
    }
    private String money(String value) { return "—".equals(value)?value:value+" ₽"; }
    private void showHome() {
        title("Рынок под наблюдением","Последние сохранённые котировки. Без торговых советов.");
        JSONObject stats=summary==null?null:summary.optJSONObject("stats");
        if(stats!=null) card("Объём наблюдений",str(stats,"daily")+" свечей",
                str(stats,"stages")+" стадий памяти · "+str(stats,"instruments")+" инструментов");
        JSONArray watch=summary==null?null:summary.optJSONArray("watch");
        if(watch!=null) for(int i=0;i<watch.length();i++) {
            JSONObject w=watch.optJSONObject(i);if(w==null)continue;
            card(str(w,"secid")+" · "+str(w,"shortname"),money(str(w,"last_price")),
                "За 30 дней: "+str(w,"return_30d_pct")+"% · Под наблюдением");
        }
        add(content,text("Никаких команд «Бери сейчас», пока стратегия не доказала качество на независимых данных.",13,GREEN,false),12);
    }
    private void showAnalyst() {
        title("Перспективные кандидаты","Исследовательский список, а не сигналы на покупку.");
        JSONArray rows=analyst==null?null:analyst.optJSONArray("candidates");
        if(rows==null||rows.length()==0) card("Кандидатов пока нет","","Сервер не подтвердил условия отбора.");
        else {
            int n=Math.min(rows.length(),12);
            for(int i=0;i<n;i++) {
                JSONObject r=rows.optJSONObject(i);if(r==null)continue;
                card(str(r,"secid")+" · "+str(r,"shortname"),money(str(r,"last_price")),
                    "30 дней: "+str(r,"return_30d_pct")+"% · Исследование");
            }
        }
        add(content,text("Исторические тесты v0.8 ещё не подтвердили преимущество для реальных сделок.",13,GOLD,false),10);
    }
    private void showSystem() {
        title("Состояние системы","История, проверка памяти и процессы Cron.");
        JSONObject st=system==null?null:system.optJSONObject("storage");
        if(st!=null)card("Сохранено свечей",str(st,"daily"),"База инвестиционного анализа");
        JSONObject audit=system==null?null:system.optJSONObject("memory_audit");
        if(audit!=null)card("Контроль целостности",str(audit,"overall"),"Проверка сохранённых стадий");
        JSONObject hist=system==null?null:system.optJSONObject("universe_history");
        if(hist!=null) {
            JSONObject symbols=hist.optJSONObject("symbols");
            if(symbols!=null) {
                int completed=0,total=0;
                java.util.Iterator<String> names=symbols.keys();
                while(names.hasNext()) {
                    JSONObject x=symbols.optJSONObject(names.next());
                    total++;if(x!=null&&x.optBoolean("finished"))completed++;
                }
                card("История за 3 года",completed+" из "+total,
                    "Загрузка продолжается автоматически, без участия Android");
            }
        }
        JSONObject research=system==null?null:system.optJSONObject("universe_research");
        if(research!=null) card("Историческая проверка",str(research,"total_signals")+" условных сигналов",
            "Прибыльных: "+str(research,"total_wins")+" · Статус: "+str(research,"gate"));
        JSONArray jobs=system==null?null:system.optJSONArray("jobs");
        if(jobs!=null&&jobs.length()>0) {
            add(content,text("ПОСЛЕДНИЕ ПРОЦЕССЫ",12,GOLD,true),10);
            for(int i=0;i<Math.min(5,jobs.length());i++) {
                JSONObject j=jobs.optJSONObject(i);if(j==null)continue;
                card(str(j,"job_name"),str(j,"status"),str(j,"started_at"));
            }
        }
        add(content,text("Приложение не управляет Cron, не загружает котировки и не совершает сделки.",12,MUTED,false),10);
    }
    private void refresh() {
        if(loading)return;
        loading=true;notice.setText("Обновляем данные сервера…");
        new Thread(()->{
            try {
                JSONObject s=new JSONObject(request("GET","api.php?action=summary",null));
                JSONObject a=new JSONObject(request("GET","api.php?action=analyst",null));
                JSONObject y=new JSONObject(request("GET","api.php?action=system",null));
                runOnUiThread(()->{
                    summary=s;analyst=a;system=y;loading=false;
                    notice.setText("Обновлено · "+str(s,"server_time")+" МСК");setTab(activeTab);
                });
            } catch(Exception ex) {
                runOnUiThread(()->{loading=false;notice.setText("Нет связи: "+ex.getMessage());});
            }
        }).start();
    }
}
