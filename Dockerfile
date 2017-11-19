# Builds a Docker image with Ubuntu 16.04, Python 3, Jupyter Notebook,
# CGNS/pyCGNS and MOAB/pyMOAB for multiphysics coupling with parallel suppport
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

# Use fenics-desktop as base image
FROM unifem/fenics-desktop:latest
LABEL maintainer "Xiangmin Jiao <xmjiao@gmail.com>"

USER root
WORKDIR /tmp

# Install system packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        automake autogen autoconf libtool \
        libhdf5-openmpi-dev \
        libnetcdf-dev netcdf-bin \
        libmetis5 libmetis-dev \
        \
        tk-dev \
        libglu1-mesa-dev \
        libxmu-dev && \
    apt-get clean && \
    pip3 install -U \
        cython \
        nose && \
    rm -rf /var/lib/apt/lists/* /tmp/*

# Install CGNS from source with parallel enabled
RUN cd /tmp && \
    mkdir /usr/lib/hdf5 && \
    ln -s -f /usr/include/hdf5/openmpi /usr/lib/hdf5/include && \
    ln -s -f /usr/lib/x86_64-linux-gnu/hdf5/openmpi /usr/lib/hdf5/lib  && \
    git clone --depth=1 -b master https://github.com/CGNS/CGNS.git && \
    cd CGNS/src && \
    export CC="mpicc" && \
    export LIBS="-Wl,--no-as-needed -ldl -lz -lsz -lpthread" && \
    ./configure --enable-64bit --with-zlib --with-hdf5=/usr/lib/hdf5 \
        --enable-cgnstools --enable-lfs --enable-shared && \
    sed -i 's/TKINCS =/TKINCS = -I\/usr\/include\/tcl/' cgnstools/make.defs && \
    make -j2 && make install && \
    rm -rf /tmp/CGNS

# Install pyCGNS from source
RUN cd /tmp && \
    git clone --depth=1 -b master https://github.com/unifem/pyCGNS.git && \
    cd pyCGNS && \
    python3 setup.py build \
        --includes=/usr/include/hdf5/openmpi:/usr/include/openmpi \
        --libraries=/usr/lib/x86_64-linux-gnu/hdf5/openmpi && \
    python3 setup.py install && \
    rm -rf /tmp/pyCGNS

# Install MOAB and pymoab from sources
RUN cd /tmp && \
    git clone --depth=1 https://bitbucket.org/fathomteam/moab.git && \
    cd moab && \
    autoreconf -fi && \
    ./configure \
        --prefix=/usr/local \
        --with-mpi \
        CC=mpicc \
        CXX=mpicxx \
        FC=mpif90 \
        F77=mpif77 \
        --enable-optimize \
        --enable-shared=yes \
        --with-blas=-lopenblas \
        --with-lapack=-lopenblas \
        --with-scotch=/usr/lib \
        --with-metis=/usr/lib/x86_64-linux-gnu \
        --with-eigen3=/usr/include/eigen3 \
        --with-x \
        --with-cgns \
        --with-netcdf \
        --with-hdf5=/usr/lib/hdf5 \
        --with-hdf5-ldflags="-L/usr/lib/hdf5/lib" \
        --enable-ahf=yes \
        --enable-tools=yes && \
    make -j2 && make install && \
    \
    cd pymoab && \
    python3 setup.py install && \
    rm -rf /tmp/moab

ADD image/home $DOCKER_HOME

########################################################
# Customization for user
########################################################

USER $DOCKER_USER
WORKDIR $DOCKER_HOME
USER root
