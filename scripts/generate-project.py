"""Generate the small Xcode project with stable IDs; no third-party dependencies."""
from pathlib import Path
import hashlib
import re
root = Path(__file__).resolve().parents[1]
existing_project = root / 'WakeUpPlz.xcodeproj/project.pbxproj'
existing_text = existing_project.read_text() if existing_project.exists() else ''
team_match = re.search(r'DEVELOPMENT_TEAM\s*=\s*([A-Z0-9]+);', existing_text)
development_team = team_match.group(1) if team_match else None
def uid(value): return hashlib.sha1(value.encode()).hexdigest()[:24].upper()
files = sorted((root / 'WakeUpPlz').rglob('*.swift')) + sorted((root / 'WakeUpPlz/Resources').glob('*.wav')) + sorted((root / 'WakeUpPlz/Resources').glob('*.xcassets'))
objects = []
def add(key, body): objects.append(f'{uid(key)} = {{ {body} }};')
refs, sources, resources = [], [], []
for file in files:
    path = file.relative_to(root).as_posix(); file_id = uid(path); build_id = uid('build'+path)
    refs.append(file_id)
    typ = {'.swift': 'sourcecode.swift', '.wav': 'audio.wav', '.xcassets': 'folder.assetcatalog'}[file.suffix]
    add(path, f'isa = PBXFileReference; lastKnownFileType = {typ}; path = "{path}"; sourceTree = SOURCE_ROOT;')
    add('build'+path, f'isa = PBXBuildFile; fileRef = {file_id};')
    (sources if file.suffix == '.swift' else resources).append(build_id)
add('app', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = WakeUpPlz.app; sourceTree = BUILT_PRODUCTS_DIR;')
add('group', f'isa = PBXGroup; children = ({",".join(refs + [uid("products")])}); sourceTree = "<group>";')
add('products', f'isa = PBXGroup; children = ({uid("app")}); name = Products; sourceTree = "<group>";')
for key, typ, contents in [('sources','PBXSourcesBuildPhase', sources),('resources','PBXResourcesBuildPhase',resources),('frameworks','PBXFrameworksBuildPhase',[])]:
    add(key, f'isa = {typ}; buildActionMask = 2147483647; files = ({",".join(contents)}); runOnlyForDeploymentPostprocessing = 0;')
add('target', f'isa = PBXNativeTarget; buildConfigurationList = {uid("targetconfigs")}; buildPhases = ({uid("sources")},{uid("frameworks")},{uid("resources")}); buildRules = (); dependencies = (); name = WakeUpPlz; productName = WakeUpPlz; productReference = {uid("app")}; productType = "com.apple.product-type.application";')
add('project', f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; }}; buildConfigurationList = {uid("projectconfigs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = ko; hasScannedForEncodings = 0; knownRegions = (ko,en,Base); mainGroup = {uid("group")}; productRefGroup = {uid("products")}; projectDirPath = ""; projectRoot = ""; targets = ({uid("target")});')
for scope in ['project','target']:
    for config in ['Debug','Release']:
        settings = 'SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 26.0; SWIFT_VERSION = 6.0; CLANG_ENABLE_MODULES = YES;'
        if scope == 'target':
            settings += ' PRODUCT_NAME = "$(TARGET_NAME)"; PRODUCT_BUNDLE_IDENTIFIER = com.luail.WakeUpPlz; TARGETED_DEVICE_FAMILY = 1; CODE_SIGN_STYLE = Automatic; GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_CFBundleDisplayName = WakeUpPlz; INFOPLIST_FILE = WakeUpPlz/App/Info.plist; INFOPLIST_KEY_UILaunchScreen_Generation = YES; INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES; INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait; SUPPORTS_MACCATALYST = NO; SWIFT_EMIT_LOC_STRINGS = YES; ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; MARKETING_VERSION = 0.1; CURRENT_PROJECT_VERSION = 15;'
        if scope == 'target' and development_team:
            settings += f' DEVELOPMENT_TEAM = {development_team};'
        settings += ' SWIFT_OPTIMIZATION_LEVEL = "-Onone"; SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG; DEBUG_INFORMATION_FORMAT = dwarf;' if config == 'Debug' else ' SWIFT_COMPILATION_MODE = wholemodule; SWIFT_OPTIMIZATION_LEVEL = "-O";'
        add(scope+config, f'isa = XCBuildConfiguration; buildSettings = {{ {settings} }}; name = {config};')
    add(scope+'configs', f'isa = XCConfigurationList; buildConfigurations = ({uid(scope+"Debug")},{uid(scope+"Release")}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
(root/'WakeUpPlz.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+'\n}; rootObject = '+uid('project')+'; }\n')
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="WakeUpPlz.app" BlueprintName="WakeUpPlz" ReferencedContainer="container:WakeUpPlz.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid('target')}" BuildableName="WakeUpPlz.app" BlueprintName="WakeUpPlz" ReferencedContainer="container:WakeUpPlz.xcodeproj"/></BuildableProductRunnable></LaunchAction></Scheme>'''
(root/'WakeUpPlz.xcodeproj/xcshareddata/xcschemes/WakeUpPlz.xcscheme').write_text(scheme)
