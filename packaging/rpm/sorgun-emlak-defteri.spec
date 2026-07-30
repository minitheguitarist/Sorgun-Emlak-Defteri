Name:           sorgun-emlak-defteri
Version:        1.0.7
Release:        1%{?dist}
Summary:        Çevrimdışı emlak ve müşteri takip uygulaması

License:        GPL-3.0-or-later
URL:            https://github.com/minitheguitarist/Sorgun-Emlak-Defteri
BuildArch:      x86_64

Requires:       gtk3
Requires:       xdg-utils

%description
Sorgun Emlak Defteri; ilanları, müşterileri, fiyat geçmişini ve fotoğrafları
yerel olarak saklayan Flutter tabanlı bir masaüstü uygulamasıdır.

%prep

%build

%install
install -d %{buildroot}%{_libexecdir}/sorgun-emlak-defteri
cp -a %{bundle_dir}/. %{buildroot}%{_libexecdir}/sorgun-emlak-defteri/

install -Dpm 0755 \
  %{repo_dir}/packaging/linux/sorgun-emlak-defteri \
  %{buildroot}%{_bindir}/sorgun-emlak-defteri
install -Dpm 0644 \
  %{repo_dir}/packaging/linux/com.sorgunemlak.defter.desktop \
  %{buildroot}%{_datadir}/applications/com.sorgunemlak.defter.desktop
install -Dpm 0644 \
  %{repo_dir}/packaging/linux/sorgun-emlak-defteri.png \
  %{buildroot}%{_datadir}/icons/hicolor/512x512/apps/com.sorgunemlak.defter.png
install -Dpm 0644 \
  %{repo_dir}/LICENSE \
  %{buildroot}%{_licensedir}/%{name}/LICENSE

%files
%license %{_licensedir}/%{name}/LICENSE
%{_bindir}/sorgun-emlak-defteri
%{_libexecdir}/sorgun-emlak-defteri/
%{_datadir}/applications/com.sorgunemlak.defter.desktop
%{_datadir}/icons/hicolor/512x512/apps/com.sorgunemlak.defter.png

%changelog
* Thu Jul 30 2026 Sorgun Emlak Defteri <noreply@example.com> - 1.0.7-1
- Linux masaüstü ilk paketi
