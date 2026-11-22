package com.example.neonsurvivor;
import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.WebChromeClient;
import android.webkit.ConsoleMessage;
import android.util.Log;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.view.WindowManager;
import java.io.InputStream;
import java.util.Collections;
public class MainActivity extends Activity {
 private WebView web;
 private static final String ORIGIN="https://appassets.androidplatform.net/assets/";
 @Override public void onCreate(Bundle state){
  super.onCreate(state);getWindow().setFlags(1024,1024);
  web=new WebView(this);
  web.setWebViewClient(new WebViewClient(){
   @Override public WebResourceResponse shouldInterceptRequest(WebView view,WebResourceRequest request){
    String url=request.getUrl().toString();
    if(!url.startsWith(ORIGIN))return null;
    String path=url.substring(ORIGIN.length()).split("[?#]",2)[0];
    if(path.contains(".."))return new WebResourceResponse("text/plain","UTF-8",404,"Not Found",Collections.emptyMap(),new java.io.ByteArrayInputStream(new byte[0]));
    String mime=path.endsWith(".js")?"text/javascript":path.endsWith(".html")?"text/html":path.endsWith(".svg")?"image/svg+xml":path.endsWith(".css")?"text/css":"application/octet-stream";
    try{InputStream stream=getAssets().open(path);return new WebResourceResponse(mime,"UTF-8",stream);}
    catch(Exception e){return new WebResourceResponse("text/plain","UTF-8",404,"Not Found",Collections.emptyMap(),new java.io.ByteArrayInputStream(new byte[0]));}
   }
  });
  web.setWebChromeClient(new WebChromeClient(){@Override public boolean onConsoleMessage(ConsoleMessage message){Log.e("AFTERFALL_WEBGL",message.message()+" @ "+message.sourceId()+":"+message.lineNumber());return true;}});
  web.setLayerType(android.view.View.LAYER_TYPE_HARDWARE,null);
  web.getSettings().setJavaScriptEnabled(true);
  web.getSettings().setDomStorageEnabled(true);
  web.getSettings().setAllowFileAccess(false);
  setContentView(web);
  web.loadUrl(ORIGIN+"index.html");
 }
 @Override protected void onDestroy(){if(web!=null)web.destroy();super.onDestroy();}
}
