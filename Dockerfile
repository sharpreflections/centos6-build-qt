FROM sharpreflections/centos6-build-gcc:gcc-4.8.5
LABEL maintainer="dennis.brendel@sharpreflections.com"

ARG gcc=gcc-4.8.5
ARG icc=icc-19.0
ARG qt_major=5.9
ARG qt_minor=.9
ARG qt_version=${qt_major}${qt_minor}
ARG qt_string=qt-everywhere-opensource-src

ARG prefix=/opt

WORKDIR /build/
COPY versiontag599.patch /build/
COPY intel19.patch /build/

ENV PATH=$prefix/qt-${qt_version}-icc19/bin:$prefix/$icc/bin:$prefix/$gcc/bin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/bin
ENV LD_LIBRARY_PATH=$prefix/$icc/compilers_and_libraries/linux/lib/intel64_lin/:$prefix/$gcc/lib64
ENV CC=icc
ENV CXX=icpc

#mounts="$INTEL_DIR:/opt/icc-19.0
#        $LIC_DIR:/root/Licenses"


RUN yum -y install centos-release-scl && \
    yum -y install python27 xz glibc-headers glibc-devel mesa-libGL-devel mesa-libEGL-devel openssl-devel \
               fontconfig-devel dbus-devel libXcomposite-devel libXcursor-devel libXi-devel libXrandr-devel \
               libXtst-devel gperf expat-devel xkeyboard-config && \
    source /opt/rh/python27/enable && \

    echo "Downloading Qt5 ${qt_version}:" && \
      curl --remote-name --location --progress-bar http://download.qt.io/official_releases/qt/${qt_major}/${qt_version}/single/${qt_string}-${qt_version}.tar.xz && \
      curl --remote-name --location --silent http://download.qt.io/official_releases/qt/${qt_major}/${qt_version}/single/md5sums.txt && \
  sed --in-place '/.*\.zip/d' md5sums.txt && \

  echo -n "Verifying file.." && \
    md5sum --quiet --check md5sums.txt && \
  echo " done" && \

  echo -n "Extracting qt5.. " && \
    tar xf ${qt_string}-${qt_version}.tar.xz && \
  echo " done" && \

  # Fix build with Intel Compiler 19.0 and remove the symbol versions for upward compatibility
  cd ${qt_string}-${qt_version} && \
  patch -p1 -i ../intel19.patch && \
  patch -p1 -i ../versiontag599.patch && \
  cd /build/ && \

  mkdir build && cd build && \
  ../${qt_string}-${qt_version}/configure --prefix=$prefix/${qt_version}-icc19 \
                -opensource -confirm-license \
                -shared                      \
                -c++std c++11                \
                -platform linux-icc-64       \
                -no-pch                      \
                -ssl                         \
                -fontconfig                  \
                -system-freetype             \
                -qt-zlib                     \
                -qt-libjpeg                  \
                -qt-libpng                   \
                -qt-xcb                      \
                -nomake examples             \
                -nomake tests                \
                -no-sse4.1 -no-sse4.2        \
                -no-avx -no-avx2 -no-avx512  \
                -no-rpath                    \
                -no-cups                     \
                -no-iconv                    \
                -no-gtk                      \
                -no-glib                     \
                -no-icu                      \
                -no-webrtc                   \
                -no-pepper-plugins           \
                -no-spellchecker             \
                -skip qt3d                   \
                -skip qtactiveqt             \
                -skip qtandroidextras        \
                -skip qtcanvas3d             \
                -skip qtcharts               \
                -skip qtconnectivity         \
                -skip qtdatavis3d            \
                -skip qtgamepad              \
                -skip qtgraphicaleffects     \
                -skip qtimageformats         \
                -skip qtlocation             \
                -skip qtmacextras            \
                -skip qtmultimedia           \
                -skip qtnetworkauth          \
                -skip qtpurchasing           \
                -skip qtsensors              \
                -skip qtserialbus            \
                -skip qtserialport           \
                -skip qtspeech               \
                -skip qttranslations         \
                -skip qtvirtualkeyboard      \
                -skip qtwayland              \
                -skip qtwebsockets           \
                -skip qtwinextras         && \
# Not skipping: qtbase
#               qtdeclarative
#               qtdoc
#               qtimageformats
#               qtquickcontrols  # required by qtwebengine
#               qtquickcontrols2
#               qtremoteobjects
#               qtscxml
#               qtscript
#               qtsvg
#               qttools
#               qtwebchannel     # required by qtwebengine
#               qtwebengine
#               qtwebview
#               qtx11extras
#               qtxmlpatterns

make --jobs=$(nproc) && make install && \
yum -y history undo last && \
rm -rf /build/* && \

# Don't carry gcc over, only Qt5
rm -rf $prefix/gcc*

# Fix private include dir bug
 RUN sed --in-place 's:\(set(Qt5Gui_PRIVATE_INCLUDE_DIRS\) ""):\1 "${_qt5Gui_install_prefix}/include/QtGui/${Qt5Gui_VERSION_STRING}" "${_qt5Gui_install_prefix}/include/QtGui/${Qt5Gui_VERSION_STRING}/QtGui"):' $prefix/qt-${qt_major}${qt_minor}-icc19/lib/cmake/Qt5Gui/Qt5GuiConfig.cmake && \
     sed --in-place 's:\(set(Qt5Core_PRIVATE_INCLUDE_DIRS\) ""):\1 "${_qt5Core_install_prefix}/include/QtCore/${Qt5Core_VERSION_STRING}" "${_qt5Core_install_prefix}/include/QtCore/${Qt5Core_VERSION_STRING}/QtCore"):' $prefix/qt-${qt_major}${qt_minor}-icc19/lib/cmake/Qt5Core/Qt5CoreConfig.cmak

