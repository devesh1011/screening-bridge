"""Generate a dependency-free Xcode project with application and test targets."""
from pathlib import Path
import argparse
import hashlib
import json

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--team', help='Existing Apple development team for physical-device signing')
args=parser.parse_args()
objects={}
def uid(key):return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def obj(key,value):objects[uid(key)]=value;return uid(key)
def q(value):return json.dumps(str(value))
def array(values):return '('+','.join(values)+')'

product_refs=[];groups=[];targets=[]
for name,folder,kind in [('ScreeningBridge','ScreeningBridge','application'),('ScreeningBridgeTests','ScreeningBridgeTests','bundle.unit-test'),('ScreeningBridgeUITests','ScreeningBridgeUITests','bundle.ui-testing')]:
    files=[];buildfiles=[]
    for f in sorted((root/folder).glob('*.swift')):
        ref=obj(str(f.relative_to(root)),f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(f.name)}; sourceTree = "<group>";')
        files.append(ref);buildfiles.append(obj('build-'+str(f.relative_to(root)),f'isa = PBXBuildFile; fileRef = {ref};'))
    resources=[]
    if kind=='application':
        ref=obj('assets','isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>";')
        files.append(ref);resources.append(obj('assets-build',f'isa = PBXBuildFile; fileRef = {ref};'))
    groups.append(obj(folder+'-group',f'isa = PBXGroup; path = {q(folder)}; children = {array(files)}; sourceTree = "<group>";'))
    ext='app' if kind=='application' else 'xctest'
    product=obj(name+'-product',f'isa = PBXFileReference; explicitFileType = {q("wrapper.application" if kind=="application" else "wrapper.cfbundle")}; path = {q(name+"."+ext)}; sourceTree = BUILT_PRODUCTS_DIR;')
    product_refs.append(product)
    sources=obj(name+'-sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(buildfiles)}; runOnlyForDeploymentPostprocessing = 0;')
    res=obj(name+'-resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {array(resources)}; runOnlyForDeploymentPostprocessing = 0;')
    configs=[]
    for config in ['Debug','Release']:
        settings={'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'com.devesh.screeningbridge'+('' if kind=='application' else '.'+name),'GENERATE_INFOPLIST_FILE':'YES','SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'26.0','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SDKROOT':'iphoneos','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if config=='Debug' else '', 'ENABLE_TESTABILITY':'YES' if config=='Debug' else 'NO'}
        if args.team:settings['DEVELOPMENT_TEAM']=args.team
        if kind=='application':settings.update({'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','INFOPLIST_KEY_CFBundleDisplayName':'Screening Bridge','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.productivity','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone':'UIInterfaceOrientationPortrait','ENABLE_PREVIEWS':'YES'})
        elif kind=='bundle.unit-test':settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/ScreeningBridge.app/ScreeningBridge','BUNDLE_LOADER':'$(TEST_HOST)'})
        else:settings.update({'TEST_TARGET_NAME':'ScreeningBridge'})
        configs.append(obj(name+config,f'isa = XCBuildConfiguration; name = {config}; buildSettings = {{'+''.join(f'{k} = {q(v)};' for k,v in settings.items())+'};'))
    configlist=obj(name+'-config',f'isa = XCConfigurationList; buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
    deps=[]
    if kind!='application':
        proxy=obj(name+'-proxy',f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("ScreeningBridge-target")}; remoteInfo = ScreeningBridge;')
        deps.append(obj(name+'-dependency',f'isa = PBXTargetDependency; target = {uid("ScreeningBridge-target")}; targetProxy = {proxy};'))
    targets.append(obj(name+'-target',f'isa = PBXNativeTarget; name = {name}; productName = {name}; productReference = {product}; productType = {q("com.apple.product-type."+kind)}; buildConfigurationList = {configlist}; buildPhases = {array([sources,res])}; buildRules = (); dependencies = {array(deps)};'))

products=obj('products',f'isa = PBXGroup; name = Products; children = {array(product_refs)}; sourceTree = "<group>";')
main=obj('main',f'isa = PBXGroup; children = {array(groups+[products])}; sourceTree = "<group>";')
configs=[obj('project-'+c,f'isa = XCBuildConfiguration; name = {c}; buildSettings = {{ CLANG_ENABLE_MODULES = YES; DEBUG_INFORMATION_FORMAT = {q("dwarf" if c=="Debug" else "dwarf-with-dsym")}; }};') for c in ['Debug','Release']]
projectconfig=obj('project-config',f'isa = XCConfigurationList; buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2710; BuildIndependentTargetsInParallel = YES; }}; buildConfigurationList = {projectconfig}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; knownRegions = (en,Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = {array(targets)};')
proj=root/'ScreeningBridge.xcodeproj';proj.mkdir(exist_ok=True)
(proj/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+''.join(f'{k} = {{ {v} }};\n' for k,v in objects.items())+'}; rootObject = '+uid('project')+'; }\n')
scheme=proj/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
def ref(name):return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name+"-target")}" BuildableName="{name}.{ "app" if name=="ScreeningBridge" else "xctest"}" BlueprintName="{name}" ReferencedContainer="container:ScreeningBridge.xcodeproj"/>'
(scheme/'ScreeningBridge.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2710" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref('ScreeningBridge')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">{ref('ScreeningBridgeTests')}</TestableReference><TestableReference skipped="NO" parallelizable="NO">{ref('ScreeningBridgeUITests')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('ScreeningBridge')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref('ScreeningBridge')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(proj)
