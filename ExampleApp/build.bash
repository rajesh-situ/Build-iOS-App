#############################################################
# build.bash
#############################################################

#!/bin/bash

# Exit this script immediately if any of the commands fails
set -e

PROJECT_NAME=ExampleApp

# The product of this script. This is the actual app bundle!
BUNDLE_DIR=${PROJECT_NAME}.app

# A place for temporary files needed for building
TEMP_DIR=_BuildTemp


#############################################################
echo → Step 1: Prepare Working Folders
#############################################################

# Delete existing folders from previous builds
rm -rf ${BUNDLE_DIR}
rm -rf ${TEMP_DIR}

mkdir ${BUNDLE_DIR}
echo ✅ Create ${BUNDLE_DIR} folder

mkdir ${TEMP_DIR}
echo ✅ Create ${TEMP_DIR} folder


#############################################################
echo → Step 2: Compile Swift Files
#############################################################

# The root directory of the project sources
SOURCE_DIR=ExampleApp

# All Swift files in the source directory
SWIFT_SOURCE_FILES=${SOURCE_DIR}/*.swift

# Target architecture we want to build for
TARGET=x86_64-apple-ios12-simulator

# Path to the SDK we want to use for compiling
SDK_PATH=$(xcrun --show-sdk-path --sdk iphonesimulator)

swiftc ${SWIFT_SOURCE_FILES} \
  -sdk ${SDK_PATH} \
  -target ${TARGET} \
  -emit-executable \
  -o ${BUNDLE_DIR}/${PROJECT_NAME}

echo ✅ Compile Swift source files ${SWIFT_SOURCE_FILES}

#############################################################
echo → Step 3: Compile Storyboards
#############################################################

# All storyboards in the Base.lproj directory
STORYBOARDS=${SOURCE_DIR}/Base.lproj/*.storyboard

# The output folder for compiled storyboards
STORYBOARD_OUT_DIR=${BUNDLE_DIR}/Base.lproj

mkdir -p ${STORYBOARD_OUT_DIR}
echo ✅ Create ${STORYBOARD_OUT_DIR} folder

for storyboard_path in ${STORYBOARDS}; do
  #
  ibtool $storyboard_path \
    --compilation-directory ${STORYBOARD_OUT_DIR}

  echo ✅ Compile $storyboard_path
done

#############################################################
echo → Step 4: Process and Copy Info.plist
#############################################################

# The location of the original Info.plist file
ORIGINAL_INFO_PLIST=${SOURCE_DIR}/Info.plist

# The location of the temporary Info.plist copy for editing
TEMP_INFO_PLIST=${TEMP_DIR}/Info.plist

# The location of the processed Info.plist in the app bundle
PROCESSED_INFO_PLIST=${BUNDLE_DIR}/Info.plist

# The bundle identifier of the resulting app
APP_BUNDLE_IDENTIFIER=com.vojtastavik.${PROJECT_NAME}

cp ${ORIGINAL_INFO_PLIST} ${TEMP_INFO_PLIST}
echo ✅ Copy ${ORIGINAL_INFO_PLIST} to ${TEMP_INFO_PLIST}


# A command line tool for dealing with plists
PLIST_BUDDY=/usr/libexec/PlistBuddy

# Set the correct name of the executable file we created at step 2
${PLIST_BUDDY} -c "Set :CFBundleExecutable ${PROJECT_NAME}" ${TEMP_INFO_PLIST}
echo ✅ Set CFBundleExecutable to ${PROJECT_NAME}

# Set a valid bundle indentifier
${PLIST_BUDDY} -c "Set :CFBundleIdentifier ${APP_BUNDLE_IDENTIFIER}" ${TEMP_INFO_PLIST}
echo ✅ Set CFBundleIdentifier to ${APP_BUNDLE_IDENTIFIER}

# Set the proper bundle name
${PLIST_BUDDY} -c "Set :CFBundleName ${PROJECT_NAME}" ${TEMP_INFO_PLIST}
echo ✅ Set CFBundleName to ${PROJECT_NAME}

# Copy processed Info.plist to the app bundle
cp ${TEMP_INFO_PLIST} ${PROCESSED_INFO_PLIST}
echo ✅ Copy ${TEMP_INFO_PLIST} to ${PROCESSED_INFO_PLIST}

open -a "Simulator.app"
xcrun simctl install booted ExampleApp.app
xcrun simctl launch booted com.vojtastavik.ExampleApp
