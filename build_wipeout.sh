#!/usr/bin/env zsh

# ANSI colour codes
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Colour

# This gets the location of the folder where the script is run from. 
SCRIPT_DIR=${0:a:h}
cd "$SCRIPT_DIR"

# Detect CPU architecture
ARCH_NAME="$(uname -m)"

echo "\n${PURPLE}This script is for compiling a native macOS build of:"
echo "${GREEN}WipEout${NC}"

echo "\n${PURPLE}The source code used is from a project called ${GREEN}WipEout Rewrite${NC}\n"

ARCH_NAME="$(uname -m)"
echo "${PURPLE}Your CPU architecture is ${GREEN}${ARCH_NAME}${PURPLE}, so the app can only be run on Macs with an ${GREEN}${ARCH_NAME}${PURPLE} CPU${NC}"

echo "\n${PURPLE}${GREEN}Homebrew${PURPLE} and the ${GREEN}Xcode command-line tools${PURPLE} are required to build${NC}"
echo "${PURPLE}If they are not present you will be prompted to install them${NC}\n"

PS3='Would you like to continue? '
OPTIONS=(
	"Yes"
	"Quit")
select opt in $OPTIONS[@]
do
	case $opt in
		"Yes")
			break
			;;
		"Quit")
			echo -e "${RED}Quitting${NC}"
			exit 0
			;;
		*) 
			echo "\"$REPLY\" is not one of the options..."
			echo "Enter the number of the option and press enter to select"
			;;
	esac
done

# Check if Homebrew is installed
echo "${PURPLE}Checking for Homebrew...${NC}"
if ! command -v brew &> /dev/null; then
	echo -e "${PURPLE}Homebrew not found. Installing Homebrew...${NC}"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	if [[ "${ARCH_NAME}" == "arm64" ]]; then 
		(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
		eval "$(/opt/homebrew/bin/brew shellenv)"
		else 
		(echo; echo 'eval "$(/usr/local/bin/brew shellenv)"') >> $HOME/.zprofile
		eval "$(/usr/local/bin/brew shellenv)"
	fi
	
	# Check for errors
	if [ $? -ne 0 ]; then
		echo "${RED}There was an issue installing Homebrew${NC}"
		echo "${PURPLE}Quitting script...${NC}"	
		exit 1
	fi
else
	echo -e "${PURPLE}Homebrew found. Updating Homebrew...${NC}"
	brew update
fi

## Homebrew dependencies
echo -e "${PURPLE}Checking for Homebrew dependencies...${NC}"
brew_dependency_check() {
	if [ -d "$(brew --prefix)/opt/$1" ]; then
		echo -e "${GREEN}Found $1. Checking for updates...${NC}"
			brew upgrade $1
	else
		 echo -e "${PURPLE}Did not find $1. Installing...${NC}"
		brew install $1
	fi
}

# Required Homebrew packages
deps=( cmake sdl2 )

for dep in $deps[@]
do 
	brew_dependency_check $dep
done

# Get the repository
echo "${PURPLE}Cloning the repository...${NC}"
git clone --recursive https://github.com/phoboslab/wipeout-rewrite
cd wipeout-rewrite

# Check for failure. Exit if there were any problems  
if [ $? -ne 0 ]; then
	echo -e "${RED}Error:${PURPLE} Could not clone the repo${NC}"
	exit 1
fi

# Fix SDL header
echo "${PURPLE}Fixing SDL Header issue...${NC}"
sed -i '' "s|#include <SDL2/SDL.h>|#include <SDL.h>|g" src/platform_sdl.c

# Check for failure. Exit if there were any problems  
if [ $? -ne 0 ]; then
	echo -e "${RED}Error:${PURPLE} Could not fix the SDL Header issue${NC}"
	exit 1
fi

# Configure
echo "${PURPLE}Configuring build...${NC}"
cmake . -B build -DCMAKE_PREFIX_PATH="$(brew --prefix sdl2)"

# Check for failure. Exit if there were any problems  
if [ $? -ne 0 ]; then
	echo -e "${RED}Error:${PURPLE} Could not configure CMake${NC}"
	exit 1
fi

# Build
echo "${PURPLE}Building...${NC}"
cmake --build build

# Check for failure. Exit if there were any problems  
if [ $? -ne 0 ]; then
	echo -e "${RED}Error:${PURPLE} Build failed${NC}"
	exit 1
fi

# Move back to the main directory
cd ..

# Create app bundle structure
echo "${PURPLE}Creating app bundle...${NC}"
rm -rf WipEout.app
mkdir -p WipEout.app/Contents/Resources
mkdir -p WipEout.app/Contents/MacOS

# create Info.plist
PLIST="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
  	<key>CFBundleGetInfoString</key>
  	<string>WipEout</string>
	<key>CFBundleExecutable</key>
	<string>wipeout</string>
	<key>CFBundleIconFile</key>
	<string>wipeout.icns</string>
	<key>CFBundleIdentifier</key>
	<string>com.github.phoboslab.wipeout-rewrite</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>WipEout</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSHumanReadableCopyright</key>
	<string>Unknown</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>CSResourcesFileMapped</key>
	<true/>
	<key>NSSupportsSuddenTermination</key>
	<false/>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.games</string>
</dict>
</plist>
"
echo "${PLIST}" > WipEout.app/Contents/Info.plist

# Create PkgInfo
PKGINFO="-n APPLWIPE"
echo "${PKGINFO}" > WipEout.app/Contents/PkgInfo

# Bundle resources. 
echo "${PURPLE}Copying resources...${NC}"
mv wipeout-rewrite/build/wipeout WipEout.app/Contents/MacOS/

# Check for failure. Exit if there were any problems  
if [ $? -ne 0 ]; then
	echo -e "${RED}Error:${PURPLE} Could not create app bundle${NC}"
	exit 1
fi

if [[ -a wipeout.png ]]; then 
	# Create icon if there is a file called prince1024.png in the build folder
	echo "${PURPLE}Found image file. Creating icon...${NC}"
	
	# mkdir ${GAME_ID}.iconset
	mkdir wipeout.iconset
	sips -z 16 16     wipeout.png --out wipeout.iconset/icon_16x16.png
	sips -z 32 32     wipeout.png --out wipeout.iconset/icon_16x16@2x.png
	sips -z 32 32     wipeout.png --out wipeout.iconset/icon_32x32.png
	sips -z 64 64     wipeout.png --out wipeout.iconset/icon_32x32@2x.png
	sips -z 128 128   wipeout.png --out wipeout.iconset/icon_128x128.png
	sips -z 256 256   wipeout.png --out wipeout.iconset/icon_128x128@2x.png
	sips -z 256 256   wipeout.png --out wipeout.iconset/icon_256x256.png
	sips -z 512 512   wipeout.png --out wipeout.iconset/icon_256x256@2x.png
	sips -z 512 512   wipeout.png --out wipeout.iconset/icon_512x512.png
	cp wipeout.png wipeout.iconset/icon_512x512@2x.png
	iconutil -c icns wipeout.iconset
	rm -R wipeout.iconset
	cp -R wipeout.icns WipEout.app/Contents/Resources/

	else 
	
	# Otherwise get an icon from macosicons.com
	echo "${PURPLE}Downloading an app icon from www.macosicons.com...${NC}"
	curl -o WipEout.app/Contents/Resources/wipeout.icns https://parsefiles.back4app.com/JPaQcFfEEQ1ePBxbf6wvzkPMEqKYHhPYv8boI1Rc/46462185dc20624cf034d191a720ce23_Ultimate%20Racing%202D.icns
fi

echo "${PURPLE}Downloading game resources...${NC}"
curl -o WipEout.app/Contents/Resources/wipeout-data-v01.zip https://phoboslab.org/files/wipeout-data-v01.zip
unzip WipEout.app/Contents/Resources/wipeout-data-v01.zip -d WipEout.app/Contents/Resources
rm -rf WipEout.app/Contents/Resources/wipeout-data-v01.zip

# Check for failure. Exit if there were any problems  
if [ $? -ne 0 ]; then
	echo -e "${RED}Error:${PURPLE} Could not download game resources${NC}"
	exit 1
fi

# Get an updated version of the game controller database
echo -e "Getting an updated SDL game controller DB file...."
curl -o WipEout.app/Contents/Resources/gamecontrollerdb.txt https://raw.githubusercontent.com/gabomdq/SDL_GameControllerDB/master/gamecontrollerdb.txt

# Check for failure. Exit if there were any problems  
if [ $? -ne 0 ]; then
	echo -e "${RED}Error:${PURPLE} Could not download game controller DB${NC}"
	exit 1
fi

# Bundle libs & Codesign
echo "${PURPLE}Bundling dependencies and codesigning...${NC}"
dylibbundler -of -cd -b -x WipEout.app/Contents/MacOS/wipeout -d WipEout.app/Contents/libs/

# Check for failure. Exit if there were any problems  
if [ $? -ne 0 ]; then
	echo -e "${RED}Error:${PURPLE} Could not bundle dependencies${NC}"
	exit 1
fi

echo "${PURPLE}Cleaning up...${NC}"
rm -rf wipeout-rewrite
