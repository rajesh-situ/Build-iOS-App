#############################################################
# build.bash
#############################################################

#!/bin/bash

# Exit this script immediately if any of the commands fails
# set -e

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

# Check for --device flag
if [ "$1" = "--device" ]; then                            #
  BUILDING_FOR_DEVICE=true;                               #
fi                                                        #
                                                          #
# Print the current target architecture
if [ "${BUILDING_FOR_DEVICE}" = true ]; then              #
  echo 👍 Building ${PROJECT_NAME} for device             #
else                                                      #
  echo 👍 Building ${PROJECT_NAME} for simulator          #
fi

#############################################################
echo → Step 2: Compile Swift Files
#############################################################

# The root directory of the project sources
SOURCE_DIR=ExampleApp

# All Swift files in the source directory
SWIFT_SOURCE_FILES=${SOURCE_DIR}/*.swift

# Target architecture we want to build for
TARGET=""

# Path to the SDK we want to use for compiling
SDK_PATH=""

if [ "${BUILDING_FOR_DEVICE}" = true ]; then
  # Building for device
  TARGET=arm64-apple-ios12.0
  SDK_PATH=$(xcrun --show-sdk-path --sdk iphoneos)

  # The folder inside the app bundle where we
  # will copy all required dylibs
  FRAMEWORKS_DIR=Frameworks

  # Set additional flags for the compiler
  OTHER_FLAGS="-Xlinker -rpath -Xlinker @executable_path/${FRAMEWORKS_DIR}"

else
  # Building for simulator
  TARGET=x86_64-apple-ios12.0-simulator
  SDK_PATH=$(xcrun --show-sdk-path --sdk iphonesimulator)
fi

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

#############################################################
if [ "${BUILDING_FOR_DEVICE}" != true ]; then
  # If we build for simulator, we can exit the scrip here
  echo 🎉 Building ${PROJECT_NAME} for simulator successfully finished! 🎉
  exit 0
fi
#############################################################

#############################################################
echo → Step 5: Copy Swift Runtime Libraries
#############################################################

# The folder where the Swift runtime libs live on the computer
SWIFT_LIBS_SRC_DIR=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/iphoneos

# The folder inside the app bundle where we want to copy them
SWIFT_LIBS_DEST_DIR=${BUNDLE_DIR}/${FRAMEWORKS_DIR}

# The list of all libs we want to copy
SWIFT_RUNTIME_LIBS=( libswiftCore.dylib libswiftCoreFoundation.dylib libswiftCoreGraphics.dylib libswiftCoreImage.dylib libswiftDarwin.dylib libswiftDispatch.dylib libswiftFoundation.dylib libswiftMetal.dylib libswiftObjectiveC.dylib libswiftQuartzCore.dylib libswiftSwiftOnoneSupport.dylib libswiftUIKit.dylib libswiftos.dylib )

mkdir -p ${BUNDLE_DIR}/${FRAMEWORKS_DIR}
echo ✅ Create ${SWIFT_LIBS_DEST_DIR} folder

for library_name in "${SWIFT_RUNTIME_LIBS[@]}"; do
  # Copy the library
  cp ${SWIFT_LIBS_SRC_DIR}/$library_name ${SWIFT_LIBS_DEST_DIR}/
  echo ✅ Copy $library_name to ${SWIFT_LIBS_DEST_DIR}
done

#############################################################
echo → Step 6: Code Signing
#############################################################

# The name of the provisioning file to use
# ⚠️ YOU NEED TO CHANGE THIS TO YOUR PROFILE ️️⚠️
PROVISIONING_PROFILE_NAME=2ba33fa5-299e-4570-b4e5-840a7adae973.mobileprovision

# The location of the provisioning file inside the app bundle
EMBEDDED_PROVISIONING_PROFILE=${BUNDLE_DIR}/embedded.mobileprovision

cp ~/Library/MobileDevice/Provisioning\ Profiles/${PROVISIONING_PROFILE_NAME} ${EMBEDDED_PROVISIONING_PROFILE}
echo ✅ Copy provisioning profile ${PROVISIONING_PROFILE_NAME} to ${EMBEDDED_PROVISIONING_PROFILE}

# The team identifier of your signing identity
# ⚠️ YOU NEED TO CHANGE THIS TO YOUR ID ️️⚠️
TEAM_IDENTIFIER=BC39BN4F76

# The location if the .xcent file
XCENT_FILE=${TEMP_DIR}/${PROJECT_NAME}.xcent

# The file doesn't exist but PlistBuddy will create it automatically
${PLIST_BUDDY} -c "Add :application-identifier string ${TEAM_IDENTIFIER}.${APP_BUNDLE_IDENTIFIER}" ${XCENT_FILE}
${PLIST_BUDDY} -c "Add :com.apple.developer.team-identifier string ${TEAM_IDENTIFIER}" ${XCENT_FILE}

echo ✅ Create ${XCENT_FILE}

# The id of the identity used for signing
IDENTITY=F0FA15DCCD82D24F381B5FD6C6134355475C7A81

# Sign all libraries in the bundle
for lib in ${SWIFT_LIBS_DEST_DIR}/*; do
  # Sign
  codesign \
    --force \
    --timestamp=none \
    --sign ${IDENTITY} \
    ${lib}
  echo ✅ Codesign ${lib}
done

# Sign the bundle itself
codesign \
  --force \
  --timestamp=none \
  --sign ${IDENTITY} \
  --entitlements ${XCENT_FILE} \
  ${BUNDLE_DIR}


echo ✅ Codesign ${BUNDLE_DIR}

#############################################################
echo 🎉 Building ${PROJECT_NAME} for device successfully finished! 🎉
exit 0
#############################################################

# open -a "Simulator.app"
# xcrun simctl install booted ExampleApp.app
# xcrun simctl launch booted com.vojtastavik.ExampleApp
