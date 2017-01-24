#!/bin/bash
#
# cd /tmp
# git clone https://github.com/exrat/LVM-MonDedie
# cd LVM-MonDedie
# chmod a+x lvm-mondedie.sh && ./lvm-mondedie.sh
#
# Auteur ex_rat
# Adapté du tuto de Xataz pour mondedie.fr http://mondedie.fr/viewtopic.php?id=7147
#
# This work is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License
# http://creativecommons.org/licences/by-nc-sa/4.0


# variables
CSI="\033["
CEND="${CSI}0m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"

# Ne rien modifier, la détection d'un VG existant est automatique
VGNAME="vghome"
DEV="/dev/mapper"
FSTAB="/etc/fstab"

# functions
FONCUSER () {
	echo -e "${CGREEN}Entrez le nom de l'utilisateur ruTorrent pour le volume lvm :${CEND}"
	read -r USER
}

FONCTAILLE () {
	echo -e "${CGREEN}Entrez la taille de volume souhaité (Chiffre rond sans virgule et en GiB) :${CEND}"
	read -r GIB
	TAILLE=$(echo "scale=2 ; $GIB" | bc | cut -d. -f1)
}

FONCVG () {
	TESTVG=$(lvm vgscan | sed '1d' |cut -d '"' -f2)
	if [ "$TESTVG" = "" ]; then
		VG="$VGNAME"
	else
		VG="$TESTVG"
	fi
}

FONCFREE () {
	FREE=$( vgdisplay "$VG" | grep -w Free)
	echo -e "${CBLUE}Place disponible${CEND} ${CRED}(en GiB)${CEND}\n${CYELLOW}$FREE${CEND}"
}

FONCOCCUP () {
	OCCUP=$( lvdisplay "$DEV"/"$VG"-"$USER" | grep -w Size)
	echo -e "${CBLUE}Place occupé par l'utilisateur${CEND} ${CRED}(en GiB)${CEND}\n${CYELLOW}$OCCUP${CEND}"
}


clear
echo -e "${CBLUE}                           Installation & Gestion LVM${CEND}"
echo -e "${CBLUE}
                                      |          |_)         _|
            __ \`__ \   _ \  __ \   _\` |  _ \  _\` | |  _ \   |    __|
            |   |   | (   | |   | (   |  __/ (   | |  __/   __| |
           _|  _|  _|\___/ _|  _|\__,_|\___|\__,_|_|\___|_)_|  _|
${CEND}"

while :; do
echo -e "${CGREEN}Choisissez une option${CEND}"
echo -e "${CYELLOW} 1 ${CEND} Installation LVM"
echo -e "${CYELLOW} 2 ${CEND} Rapport LVM"
echo -e "${CYELLOW} 3 ${CEND} Conversion Go en GiB"
echo -e "    *****************************"
echo -e "${CYELLOW} 4 ${CEND} Ajout d'un volume utilisateur"
echo -e "${CYELLOW} 5 ${CEND} Augmentation ou réduction d'un volume utilisateur"
echo -e "${CYELLOW} 6 ${CEND} Suppression complète d'un volume utilisateur"
echo -e "${CYELLOW} 7 ${CEND} Sortir"
echo -n -e "${CGREEN}Entrez votre choix :${CEND} "
read -r OPTION

case $OPTION in

	1)
		# Installation LVM
		TESTSDX=$( grep -w /home "$FSTAB" | cut -c 6-9)
		if [ "$TESTSDX" = "" ]; then
			echo -e "${CRED}Pas de partition /home disponible${CEND}"
			exit
		else
			SDX="$TESTSDX"
		fi

		apt-get install lvm2
		sed -i "s/use_lvmetad = 0/use_lvmetad = 1/g;" /etc/lvm/lvm.conf
		umount /home
		sed -i "/$SDX/d" "$FSTAB"
		pvcreate /dev/"$SDX"
		vgcreate "$VGNAME" /dev/"$SDX"
		echo "" ; vgdisplay "$VGNAME" ; echo ""
	;;

	2)
		# Rapport LVM
		echo "" ; echo -e "${CYELLOW}Attributs de groupes de volumes${CEND}" ; vgdisplay
		echo "" ; echo -e "${CYELLOW}Informations sur les volumes physiques${CEND}" ; pvs
		echo "" ; echo -e "${CYELLOW}Information sur les groupes de volumes${CEND}" ; vgs
		echo "" ; echo -e "${CYELLOW}Informations sur les volumes logiques${CEND}" ; lvs
		echo -e "${CBLUE}Toutes les tailles sont données en${CEND} ${CRED}GiB${CEND}" ; echo ""
	;;

	3)
		# Conversion
		echo "" ; echo -e "${CBLUE}Entrez la taille en${CEND} ${CYELLOW}Go${CEND} ${CBLUE}souhaité pour la convertir en ${CYELLOW}GiB${CEND} ${CBLUE}:${CEND}"
		read -r CONV
		CONVGIB=$(echo "scale=2;((($CONV/1000)*1024)*0.99)" | bc | sed "s/\,/./")
		echo -e "${CBLUE}La conversion pour "$CONV" Go est de :${CEND} ${CYELLOW}"$CONVGIB" GiB${CEND}" ; echo ""
	;;

	4)
		# Ajout volume utilisateur
		FONCVG
		echo "" ; FONCUSER
		echo "" ; FONCFREE
		echo "" ; FONCTAILLE
		lvcreate -L "$TAILLE"G -n "$USER" "$VG"
		mkfs.ext4 "$DEV"/"$VG"-"$USER"
		mkdir -p /home/"$USER"
		mount "$DEV"/"$VG"-"$USER" /home/"$USER"
		echo "$DEV/$VG-$USER        /home/$USER     ext4    defaults        0       2" >> "$FSTAB"
		tune2fs -m 0 "$DEV"/"$VG"-"$USER"
		mount -o remount /home/"$USER"
		echo "" ; df -h /home/"$USER"
		echo "" ; FONCFREE ; echo ""
	;;

	5)
		# Augmentation ou reduction de l'espace disque
		FONCVG
		echo "" ; FONCUSER
		echo "" ; FONCFREE
		echo "" ; FONCOCCUP
		echo "" ; FONCTAILLE
		umount /home/"$USER"/
		e2fsck -f "$DEV"/"$VG"-"$USER"
		SECURE=$((TAILLE-5))
		resize2fs -p "$DEV"/"$VG"-"$USER" "$SECURE"G

		if [ $? -ge 2 ]  ; then
			echo -e "${CRED}Une erreur rend l'opération impossible${CEND}"
			exit
		fi

		lvresize -L "$TAILLE"G "$DEV"/"$VG"-"$USER"
		sleep 3
		resize2fs "$DEV"/"$VG"-"$USER"
		mount "$DEV"/"$VG"-"$USER" /home/"$USER"
		echo "" ; df -h /home/"$USER"
		echo "" ; FONCFREE ; echo ""
	;;

	6)
		# Suppression d'un volume utilisateur
		FONCVG
		echo "" ; FONCUSER
		umount /home/"$USER"
		lvremove /dev/"$VG"/"$USER"
		sed -i "/$VG-$USER/d" "$FSTAB"
		rm -R /home/"$USER"
		echo "" ; FONCFREE ; echo ""
	;;

	7)
		# Sortie
		echo "" ; break
	;;

	*)
		# Invalide
		echo "" ; echo -e "${CRED}Choix Invalide${CEND}" ; echo ""
	;;

esac
done
