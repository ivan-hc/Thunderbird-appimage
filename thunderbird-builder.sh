#!/usr/bin/env bash

APP=thunderbird

# TEMPORARY DIRECTORY
mkdir -p tmp
cd ./tmp || exit 1

# DOWNLOAD APPIMAGETOOL
if ! test -f ./appimagetool; then
	wget -q https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage -O appimagetool || exit 1
	chmod a+x ./appimagetool
fi
#export URUNTIME_PRELOAD=1

# CREATE THUNDERBIRD BROWSER APPIMAGES

LAUNCHER="[Desktop Entry]
Name=Thunderbird
Comment=Send and receive mail with Thunderbird
Comment[ast]=Lleer y escribir corréu electrónicu
Comment[ca]=Llegiu i escriviu correu
Comment[cs]=Čtení a psaní pošty
Comment[da]=Skriv/læs e-post/nyhedsgruppe med Mozilla Thunderbird
Comment[de]=E-Mails und Nachrichten mit Thunderbird lesen und schreiben
Comment[el]=Διαβάστε και γράψτε γράμματα με το Mozilla Thunderbird
Comment[es]=Lea y escriba correos y noticias con Thunderbird
Comment[fi]=Lue ja kirjoita sähköposteja
Comment[fr]=Lire et écrire des courriels
Comment[gl]=Lea e escriba correo electrónico
Comment[he]=קריאה/כתיבה של דוא״ל/חדשות באמצעות Mozilla Thunderbird
Comment[hr]=Čitajte/šaljite e-poštu s Thunderbird
Comment[hu]=Levelek írása és olvasása a Thunderbirddel
Comment[it]=Per leggere e scrivere email
Comment[ja]=メールの読み書き
Comment[ko]=Mozilla Thunderbird 메일/뉴스 읽기 및 쓰기 클라이언트
Comment[nl]=E-mail/nieuws lezen en schrijven met Mozilla Thunderbird
Comment[pl]=Czytanie i wysyłanie e-maili
Comment[pt_BR]=Leia e escreva suas mensagens
Comment[ru]=Читайте и пишите письма
Comment[sk]=Čítajte a píšte poštu pomocou programu Thunderbird
Comment[sv]=Läs och skriv e-post
Comment[ug]=ئېلخەت ۋە خەۋەرلەرنى Mozilla Thunderbird دا كۆرۈش ۋە يېزىش
Comment[uk]=Читання та написання листів
Comment[vi]=Đọc và soạn thư điện tử
Comment[zh_CN]=阅读邮件或新闻
Comment[zh_TW]=以 Mozilla Thunderbird 讀寫郵件或新聞
GenericName=Mail Client (Bleeding edge)
GenericName[ast]=Client de correu
GenericName[ca]=Client de correu
GenericName[cs]=Poštovní klient
GenericName[da]=E-postklient
GenericName[de]=E-Mail-Anwendung
GenericName[el]=Λογισμικό αλληλογραφίας
GenericName[es]=Cliente de correo
GenericName[fi]=Sähköpostiohjelma
GenericName[fr]=Client de messagerie
GenericName[gl]=Cliente de correo electrónico
GenericName[he]=לקוח דוא״ל
GenericName[hr]=Klijent e-pošte
GenericName[hu]=Levelezőkliens
GenericName[it]=Client email
GenericName[ja]=電子メールクライアント
GenericName[ko]=메일 클라이언트
GenericName[nl]=E-mailprogramma
GenericName[pl]=Klient poczty
GenericName[pt_BR]=Cliente de E-mail
GenericName[ru]=Почтовый клиент
GenericName[sk]=Poštový klient
GenericName[ug]=ئېلخەت دېتالى
GenericName[uk]=Поштова програма
GenericName[vi]=Phần mềm khách quản lý thư điện tử
GenericName[zh_CN]=邮件新闻客户端
GenericName[zh_TW]=郵件用戶端
Exec=$APP %u
Terminal=false
Type=Application
Icon=thunderbird
Categories=Network;Email;
MimeType=message/rfc822;x-scheme-handler/mailto;application/x-xpinstall;
StartupNotify=true"

_create_thunderbird_appimage() {
	# Detect the channel
	if [ "$CHANNEL" != stable ]; then
		DOWNLOAD_URL="https://download.mozilla.org/?product=$APP-$CHANNEL-latest&os=linux64"
	else
		DOWNLOAD_URL="https://download.mozilla.org/?product=$APP-latest&os=linux64"
	fi

	# Download with wget or wget2
	if wget --version | head -1 | grep -q ' 1.'; then
		wget -q --no-verbose --show-progress --progress=bar "$DOWNLOAD_URL" --trust-server-names || exit 1
	else
		wget "$DOWNLOAD_URL" --trust-server-names || exit 1
	fi

	# Disable automatic updates
	#mkdir -p "$APP".AppDir && touch "$APP".AppDir/is_packaged_app || exit 1
	mkdir -p "$APP".AppDir/distribution
	cat <<-'HEREDOC' >> "$APP".AppDir/distribution/policies.json
	{
	  "policies": {
	    "DisableAppUpdate": true
	  }
	}
	HEREDOC

	# Extract the archive
	[ -e ./*tar.* ] && tar fx ./*tar.* && mv ./thunderbird/* "$APP".AppDir/ && rm -f ./*tar.* || exit 1

	# Enter the AppDir
	cd "$APP".AppDir || exit 1

	# Add the launcher and patch it depending on the release channel
	echo "$LAUNCHER" > thunderbird.desktop
	if [ "$CHANNEL" != stable ]; then
		sed -i "s/Name=Thunderbird/Name=Thunderbird ${CHANNEL^}/g" thunderbird.desktop
	fi

	# Add the icon
	cp ./chrome/icons/default/default128.png thunderbird.png
	cd .. || exit 1

	# Check the version
	VERSION=$(cat ./"$APP".AppDir/application.ini | grep "^Version=" | head -1 | cut -c 9-)

	# Create te AppRun
	cat <<-'HEREDOC' >> ./"$APP".AppDir/AppRun
	#!/bin/sh
	HERE="$(dirname "$(readlink -f "${0}")")"
	export PATH="${HERE}:${PATH}"
	export MOZ_LEGACY_PROFILES=1
	export MOZ_APP_LAUNCHER="${APPIMAGE}"
	exec "${HERE}"/thunderbird "$@"
	HEREDOC
	chmod a+x ./"$APP".AppDir/AppRun

	# Export the AppDir to an AppImage
	ARCH=x86_64 ./appimagetool -u "gh-releases-zsync|$GITHUB_REPOSITORY_OWNER|Thunderbird-appimage|continuous-$CHANNEL|*-$CHANNEL-*x86_64.AppImage.zsync" \
		./"$APP".AppDir Thunderbird-"$CHANNEL"-"$VERSION"-x86_64.AppImage || exit 1
}

CHANNEL="stable"
mkdir -p "$CHANNEL" && cp ./appimagetool ./"$CHANNEL"/appimagetool && cd "$CHANNEL" || exit 1
_create_thunderbird_appimage
cd .. || exit 1
mv ./"$CHANNEL"/*.AppImage* ./

CHANNEL="beta"
mkdir -p "$CHANNEL" && cp ./appimagetool ./"$CHANNEL"/appimagetool && cd "$CHANNEL" || exit 1
_create_thunderbird_appimage
cd .. || exit 1
mv ./"$CHANNEL"/*.AppImage* ./

CHANNEL="nightly"
mkdir -p "$CHANNEL" && cp ./appimagetool ./"$CHANNEL"/appimagetool && cd "$CHANNEL" || exit 1
_create_thunderbird_appimage
cd .. || exit 1
mv ./"$CHANNEL"/*.AppImage* ./

cd ..
mv ./tmp/*.AppImage* ./
