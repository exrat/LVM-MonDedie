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

VGNAME="vghome"
DEV="/dev/mapper"
FSTAB="/etc/fstab"

# functions
function FONCUSER ()
{
echo -e "${CGREEN}Entrez le nom d'user rutorrent pour le volume lvm :${CEND}"
read -r USER
}

function FONCTAILLE ()
{
echo -e "${CGREEN}Entrez la taille de volume souhaité (en Go) :${CEND}"
read -r TAILLE
}

function FONCFREE ()
{
FREE=$( vgdisplay "$VGNAME" | grep -w Free)
echo -e "Place disponible\n${CYELLOW}$FREE${CEND}"
}

function FONCOCCUP ()
{
OCCUP=$( lvdisplay "$DEV"/"$VGNAME"-"$USER" | grep -w Size)
echo -e "Place occupé par l'user\n${CYELLOW}$OCCUP${CEND}"
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
echo -e "${CGREEN}Choisissez une option.${CEND}"
echo -e "${CYELLOW} 1${CEND} Installation LVM"
echo -e "${CYELLOW} 2${CEND} Ajout volume utilisateur"
echo -e "${CYELLOW} 3${CEND} Augmentation ou réduction de l'espace disque"
echo -e "${CYELLOW} 4${CEND} Suppression d'un volume utilisateur"
echo -e "${CYELLOW} 5${CEND} Sortir"
echo -n -e "${CGREEN}Entrez votre choix :${CEND} "
read -r OPTION

case $OPTION in

	1 )
		# Installation LVM
		TESTSDX=$( grep -w /home "$FSTAB" | cut -c 6-9)
		if [ "$TESTSDX" = "" ]; then
			echo -e "${CRED}Pas de partition /home disponible${CEND}"
			exit
		else
			SDX="$TESTSDX"
		fi

		apt-get install lvm2
		umount /home
		sed -i "/$SDX/d" "$FSTAB"
		pvcreate /dev/"$SDX"
		vgcreate "$VGNAME" /dev/"$SDX"
		echo "" ; vgdisplay "$VGNAME" ; echo ""
	;;

	2)
		# Ajout volume user
		echo "" ; FONCUSER
		FONCFREE
		echo "" ; FONCTAILLE
		lvcreate -L "$TAILLE"G -n "$USER" "$VGNAME"
		mkfs.ext4 "$DEV"/"$VGNAME"-"$USER"
		mkdir -p /home/"$USER"
		mount "$DEV"/"$VGNAME"-"$USER" /home/"$USER"
		echo "$DEV/$VGNAME-$USER        /home/$USER     ext4    defaults        0       2" >> "$FSTAB"
		tune2fs -m 0 "$DEV"/"$VGNAME"-"$USER"
		mount -o remount /home/"$USER"
		echo "" ; df -h /home/"$USER"
		echo "" ; FONCFREE ; echo ""
	;;

	3)
		# Augmentation ou reduction de l'espace disque 
		echo "" ; FONCUSER
		echo "" ; FONCFREE
		echo "" ; FONCOCCUP
		echo "" ; FONCTAILLE
		umount /home/"$USER"/
		e2fsck -f "$DEV"/"$VGNAME"-"$USER"
		SECURE=$((TAILLE-5))
		resize2fs -p "$DEV"/"$VGNAME"-"$USER" "$SECURE"G
		# mettre controle pour au dessus
		if (($? <= 1)) ; then
			echo
			else
			echo -e "${CRED}Une erreur rend l'opération impossible${CEND}"
			exit
		fi

		lvresize -L "$TAILLE"G "$DEV"/"$VGNAME"-"$USER"
		resize2fs "$DEV"/"$VGNAME"-"$USER"
		mount "$DEV"/"$VGNAME"-"$USER" /home/"$USER"
		echo "" ; df -h /home/"$USER"
		echo "" ; FONCFREE ; echo ""
	;;

	4)
		# Suppression d'un volume utilisateur
		echo "" ; FONCUSER
		umount /home/"$USER"
		lvremove /dev/"$VGNAME"/"$USER"
		sed -i "/$VGNAME-$USER/d" "$FSTAB"
		echo "" ; FONCFREE ; echo ""
	;;

	5)
		# Sortie
		echo "" ; break
	;;

	* )
		# Invalide
		echo "" ; echo -e "${CRED}Choix Invalide${CEND}" ; echo ""
		;;

esac
done
