Name:           quitepaper
Version:        1.5.8
Release:        1%{?dist}
Summary:        Privacy-first, local-first encrypted notes and markdown journal

License:        GPL-3.0-or-later
URL:            https://github.com/blackpirateapps/quitepaper
BuildArch:      x86_64

# Turn off debuginfo generation since Flutter binaries are stripped
%global debug_package %{nil}

Requires:       gtk3 >= 3.24
Requires:       glib2 >= 2.64
Requires:       libsecret
Requires:       hicolor-icon-theme

%description
Quiet Paper is an elegant, distraction-free markdown note-taking app and daily journal
engineered with local-first, zero-knowledge encryption.

%install
rm -rf %{buildroot}
mkdir -p %{buildroot}/opt/quitepaper
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_datadir}/metainfo
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/256x256/apps
mkdir -p %{buildroot}%{_datadir}/icons/hicolor/512x512/apps

# Copy bundle
cp -a %{_sourcedir}/bundle/* %{buildroot}/opt/quitepaper/

# Symlink executable
ln -sf /opt/quitepaper/quitepaper %{buildroot}%{_bindir}/quitepaper

# Desktop & metainfo files
install -m 0644 %{_sourcedir}/linux/com.blackpiratex.quietpaper.desktop %{buildroot}%{_datadir}/applications/com.blackpiratex.quietpaper.desktop
install -m 0644 %{_sourcedir}/linux/com.blackpiratex.quietpaper.metainfo.xml %{buildroot}%{_datadir}/metainfo/com.blackpiratex.quietpaper.metainfo.xml

# Icons
install -m 0644 %{_sourcedir}/linux/assets/icon.png %{buildroot}%{_datadir}/icons/hicolor/256x256/apps/com.blackpiratex.quietpaper.png
install -m 0644 %{_sourcedir}/assets/icons/app_icon.png %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/com.blackpiratex.quietpaper.png

%post
/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :
if [ -x %{_bindir}/gtk-update-icon-cache ]; then
  %{_bindir}/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :
fi
if [ -x %{_bindir}/update-desktop-database ]; then
  %{_bindir}/update-desktop-database &>/dev/null || :
fi

%postun
/bin/touch --no-create %{_datadir}/icons/hicolor &>/dev/null || :
if [ -x %{_bindir}/gtk-update-icon-cache ]; then
  %{_bindir}/gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :
fi
if [ -x %{_bindir}/update-desktop-database ]; then
  %{_bindir}/update-desktop-database &>/dev/null || :
fi

%files
/opt/quitepaper
%{_bindir}/quitepaper
%{_datadir}/applications/com.blackpiratex.quietpaper.desktop
%{_datadir}/metainfo/com.blackpiratex.quietpaper.metainfo.xml
%{_datadir}/icons/hicolor/256x256/apps/com.blackpiratex.quietpaper.png
%{_datadir}/icons/hicolor/512x512/apps/com.blackpiratex.quietpaper.png

%changelog
* Sun Sep 21 2026 Black Pirate <dev@quitepaper.app> - 1.5.8-1
- Linux native optimization release with XDG migration, WAL mode, and GTK single-instance support.
