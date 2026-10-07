"""Rebuild AndroidSpeech.aar using existing JDK, Android SDK and Godot template.
Usage: python build_plugin.py --jdk PATH --android-jar PATH --godot-template PATH
"""
from pathlib import Path
import argparse,io,subprocess,tempfile,zipfile
args=argparse.ArgumentParser()
args.add_argument('--jdk',required=True)
args.add_argument('--android-jar',required=True)
args.add_argument('--godot-template',required=True)
options=args.parse_args()
base=Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as temp:
 work=Path(temp)
 with zipfile.ZipFile(options.godot_template) as template:
  with zipfile.ZipFile(io.BytesIO(template.read('libs/debug/godot-lib.template_debug.aar'))) as aar:
   (work/'godot.jar').write_bytes(aar.read('classes.jar'))
 subprocess.run([str(Path(options.jdk)/'bin/javac.exe'),'-source','17','-target','17','-classpath',str(work/'godot.jar')+';'+options.android_jar,'-d',str(work/'classes'),str(base/'src/AndroidSpeech.java')],check=True)
 jar=io.BytesIO()
 with zipfile.ZipFile(jar,'w') as output:
  for file in (work/'classes').rglob('*.class'): output.write(file,file.relative_to(work/'classes').as_posix())
 with zipfile.ZipFile(base/'AndroidSpeech.aar','w') as output:
  output.writestr('classes.jar',jar.getvalue())
  output.write(base/'src/AndroidManifest.xml','AndroidManifest.xml')
print('Built',base/'AndroidSpeech.aar')
