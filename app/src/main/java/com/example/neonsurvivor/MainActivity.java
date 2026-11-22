package com.example.neonsurvivor;
import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.view.WindowManager;
public class MainActivity extends Activity {
 private WebView web;
 @Override public void onCreate(Bundle state){super.onCreate(state);getWindow().setFlags(1024,1024);web=new WebView(this);web.setWebViewClient(new WebViewClient());web.getSettings().setJavaScriptEnabled(true);web.getSettings().setAllowFileAccess(true);setContentView(web);web.loadUrl("file:///android_asset/index.html");}
 @Override protected void onDestroy(){if(web!=null)web.destroy();super.onDestroy();}
}
