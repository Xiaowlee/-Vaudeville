package org.vaudeville.speech;
import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONObject;
import org.json.JSONArray;
import java.util.ArrayList;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicInteger;

public class AndroidSpeech extends GodotPlugin {
 private final ConcurrentLinkedQueue<String> events=new ConcurrentLinkedQueue<>();
 private final AtomicInteger generation=new AtomicInteger();
 private SpeechRecognizer recognizer;
 public AndroidSpeech(Godot godot){super(godot);}
 @Override public String getPluginName(){return "AndroidSpeech";}
 @UsedByGodot public boolean permitted(){return getActivity()!=null && getActivity().checkSelfPermission(Manifest.permission.RECORD_AUDIO)==PackageManager.PERMISSION_GRANTED;}
 @UsedByGodot public boolean available(){return getActivity()!=null && SpeechRecognizer.isRecognitionAvailable(getActivity());}
 @UsedByGodot public String poll(){String v;while((v=events.poll())!=null){try{if(new JSONObject(v).getInt("generation")==generation.get())return v;}catch(Exception ignored){}}return "";}
 @UsedByGodot public void open_settings(){getActivity().runOnUiThread(()->{Intent i=new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,Uri.parse("package:"+getActivity().getPackageName()));getActivity().startActivity(i);});}
 private void event(int token,String kind,String text,Bundle results){
  if(token!=generation.get())return;
  try{JSONObject obj=new JSONObject();obj.put("generation",token);obj.put("kind",kind);obj.put("text",text);obj.put("source","android_system");
   if(results!=null){ArrayList<String> words=results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);float[] scores=results.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES);JSONArray alternatives=new JSONArray();if(words!=null)for(int n=0;n<Math.min(3,words.size());n++){JSONObject alt=new JSONObject();alt.put("transcript",words.get(n));alt.put("confidence",scores!=null&&n<scores.length&&scores[n]>=0?scores[n]:JSONObject.NULL);alternatives.put(alt);}obj.put("alternatives",alternatives);}
   if(events.size()<128)events.add(obj.toString());
  }catch(Exception ignored){}
 }
 private void destroy(){if(recognizer!=null){recognizer.cancel();recognizer.destroy();recognizer=null;}}
 @UsedByGodot public void stop(){generation.incrementAndGet();events.clear();getActivity().runOnUiThread(this::destroy);}
 @UsedByGodot public void start(String language){
  int token=generation.incrementAndGet();events.clear();
  getActivity().runOnUiThread(()->{
   destroy();if(token!=generation.get())return;
   if(!permitted()){event(token,"error","Allow microphone access in Microphone settings.",null);return;}
   if(!available()){event(token,"error","No Android speech service is installed or enabled.",null);return;}
   try{
    recognizer=SpeechRecognizer.createSpeechRecognizer(getActivity());
    recognizer.setRecognitionListener(new RecognitionListener(){
     public void onReadyForSpeech(Bundle b){event(token,"ready","Listening",null);}
     public void onBeginningOfSpeech(){} public void onRmsChanged(float r){} public void onBufferReceived(byte[] b){} public void onEndOfSpeech(){}
     public void onError(int code){event(token,"error",errorText(code),null);}
     public void onResults(Bundle b){ArrayList<String> words=b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);if(words==null||words.isEmpty())event(token,"error","No words recognized. Please retry.",null);else event(token,"final",words.get(0),b);}
     public void onPartialResults(Bundle b){ArrayList<String> words=b.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);if(words!=null&&!words.isEmpty())event(token,"partial",words.get(0),b);}
     public void onEvent(int type,Bundle b){}
    });
    Intent intent=new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE,language);intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS,true);intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS,3);recognizer.startListening(intent);
   }catch(Exception e){event(token,"error","Android speech could not start: "+e.getClass().getSimpleName(),null);}
  });
 }
 private static String errorText(int code){switch(code){case 1:case 2:return "Speech service network error. Check your connection and retry.";case 3:return "Microphone is busy or unavailable. Close other recording apps.";case 6:return "No speech heard. Tap to speak again.";case 7:return "Words not recognized. Please try again.";case 8:return "Speech service busy. Wait briefly and retry.";case 9:return "Microphone permission denied. Open Microphone settings.";case 12:case 13:return "This speech language is unavailable. Try English (US).";default:return "Android speech error "+code+". Please retry.";}}
 @Override public void onMainPause(){stop();super.onMainPause();}
}
