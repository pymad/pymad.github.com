#!/bin/bash


# This scripts downloads and builds Mad-X in the correct way,
# then it downloads and builds pymad including cpymad

# Set here the name of a non-existing folder where 
# Everything can be built...
tmp=temp_folder

# Optionally, set a different install prefix:
# Libraries will be installed in $prefix/lib,
# binaries in $prefix/bin and so on
# For system wide, manual installation we recommend
# the prefix /usr/local.
prefix=$HOME/.local/

# Optionally, do not delete the temporary directory
# after installation finished..
delete_tmp=true
# The rest you don't need to worry about...

if [ -e $tmp ]
then
    echo "Path $tmp already exist"
    echo "Please delete or set another temporary folder"
    echo "Do not want to delete anything of yours by accident.."
    exit 1
fi

base=`pwd`

mkdir $tmp

find_lib() {
    if [ "$2" ]
    then
        ld -L$1 -l$2 2>/dev/null && return 1 || return 0
    else
        ld -l$1 2>/dev/null && return 1 || return 0
    fi
}

####
# Building Mad-X...
####

find_lib $prefix/lib madx
if (( $?==0 ))
then
    echo "Could not find Mad-X library"

    echo "Checking out Mad-X source..."
    svn co http://svnweb.cern.ch/guest/madx/trunk/madX/ $tmp/madX > /dev/null
    if (( $? ))
    then
        echo "checkout failed"
        exit 1
    else
        echo "Mad-X source checked out"
    fi
    cd $tmp/madX
    mkdir build; cd build
    cmake_opt="-DMADX_STATIC=OFF
               -DBUILD_SHARED_LIBS=ON
               -DCMAKE_INSTALL_PREFIX=$prefix
               -DCMAKE_BUILD_TYPE=Release"
    [[ "`uname -a`" =~ "arwin" ]] && cmake_opt="$cmake_opt -DMADX_BUNDLE=OFF"
    cmake $cmake_opt ..
    make install
else
    echo "Mad-X library already existing"
fi

# Building Pymad:
cd $base
echo "Checking out PyMad source..."
git clone git://github.com/pymad/pymad.git $tmp/pymad
if (( $? ))
then
    echo "checkout failed"
    exit 1
else
    echo "PyMad source checked out"
fi

cd $tmp/pymad/src
pybins="python2.7 python2.6 python27 python26 python2 python"
for pybin in $pybins
do
    if [ `which $pybin 2> /dev/null` ]
    then
        python=`which $pybin`
        break
    fi
done
if [ "$python" ]
then
    echo "Using python binary: $python"
else
    echo "Could not find useable python binary, failing to install pymad"
    exit 1
fi

echo "Installing PyMad..."
$python setup.py install --prefix=$prefix --record=install_manifest.txt > /dev/null
if (( $? ))
then
    echo "Installation failed"
    exit 1
else
    echo "PyMad source checked out"
fi

###
# Check installation
###
cd $tmp
$python -c 'from cern import madx;m=madx.madx()' > /dev/null 2>&1
if (( $? ))
then
    echo "It looks like the cpymad backend does not work"
    echo "Please see the web page for help, or contact one"
    echo " of the developers"
    echo "Alternatively, use the jpymad backend"
fi


###
# Create uninstall script
###

cd $tmp
echo -e "#!/bin/bash \n\n" > uninstall.sh
echo -e "flist='`cat $tmp/pymad/src/install_manifest.txt $tmp/madX/build/install_manifest.txt`'\n" >> uninstall.sh
echo -e "\nfor f in \$flist\ndo\n    rm \$f\ndone\n" >> uninstall.sh
chmod +x uninstall.sh
echo "uninstall.sh has been created"
echo "Save this script somewhere, and"
echo "execute it to remove all files we"
echo -e "have just installed\n"


###
# Cleanup...
###

echo "Removing temporary files..."
if $delete_tmp
then
    cd $base
    rm -r $tmp
fi
echo "Done"

echo -e "\n\t --- Installation has finished ---\n"
