from pathlib import Path
import sys
from story_script import import_response_template
project=Path(__file__).resolve().parents[1]
if '--overwrite' not in sys.argv:
 raise SystemExit('Import replaces graph content; recovery copies are stored outside the project. Supply --overwrite deliberately.')
source=Path(sys.argv[sys.argv.index('--source')+1]) if '--source' in sys.argv else project.parent/'Story Script/Beneath the Lines - IMPORT THIS.html'
import_response_template(project,source)
