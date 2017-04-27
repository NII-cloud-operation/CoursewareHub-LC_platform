#!/bin/bash

users=(
hydrogen
helium
lithium
beryllium
boron
carbon
nitrogen
oxygen
fluorine
neon
sodium
magnesium
aluminium
silicon
phosphorus
sulfur
chlorine
argon
potassium
calcium
scandium
titanium
vanadium
chromium
manganese
iron
cobalt
nickel
copper
zinc
gallium
germanium
arsenic
selenium
bromine
krypton
rubidium
strontium
yttrium
zirconium
niobium
molybdenum
technetium
ruthenium
rhodium
palladium
silver
cadmium
indium
tin
antimony
tellurium
iodine
xenon
caesium
barium
lanthanum
cerium
praseodymium
neodymium
promethium
samarium
europium
gadolinium
terbium
dysprosium
holmium
erbium
thulium
ytterbium
lutetium
hafnium
tantalum
tungsten
rhenium
osmium
iridium
platinum
gold
mercury
thallium
lead
bismuth
polonium
astatine
radon
francium
radium
actinium
thorium
protactinium
uranium
neptunium
plutonium
americium
curium
berkelium
californium
einsteinium
)

echo '<?php'
echo "require_once __DIR__ . '/db.php';"

echo '$user_info = array('
for i in `seq 1 50`
do
password=$(./pwgen.sh)
echo "array('mail_addr'=>'${users[$i]}@ecloud.nii.ac.jp', 'password'=>'$password'),"
done
echo ');'

echo 'add_local_users($user_info);'
echo '?>'
