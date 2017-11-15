# Builds a Docker image with Ubuntu 16.04, Python 3, Jupyter Notebook,
# CGNS/pyCGNS, MOAB/pyMOAB, and DataTransferKit for multiphysics coupling
#
# Authors:
# Xiangmin Jiao <xmjiao@gmail.com>

# Use fenics-desktop as base image
FROM unifem/fenics-desktop
LABEL maintainer "Xiangmin Jiao <xmjiao@gmail.com>"

USER root
WORKDIR /tmp

# Install system packages
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        automake autogen autoconf libtool \
        libhdf5-mpich-dev \
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

# Install CGNS
RUN cd /tmp && \
    mkdir /usr/lib/hdf5 && \
    ln -s -f /usr/include/hdf5/mpich /usr/lib/hdf5/include && \
    ln -s -f /usr/lib/x86_64-linux-gnu/hdf5/mpich /usr/lib/hdf5/lib  && \
    git clone --depth=1 -b master https://github.com/CGNS/CGNS.git && \
    cd CGNS/src && \
    export CC="mpicc.mpich" && \
    export LIBS="-Wl,--no-as-needed -ldl -lz -lsz -lpthread" && \
    ./configure --enable-64bit --with-zlib --with-hdf5=/usr/lib/hdf5 \
        --enable-cgnstools --enable-lfs --enable-shared && \
    sed -i 's/TKINCS =/TKINCS = -I\/usr\/include\/tcl/' cgnstools/make.defs && \
    make -j2 && make install && \
    rm -rf /tmp/CGNS

# Install pyCGNS
RUN cd /tmp && \
    git clone --depth=1 -b master https://github.com/unifem/pyCGNS.git && \
    cd pyCGNS && \
    python3 setup.py build \
        --includes=/usr/include/hdf5/mpich:/usr/include/mpich \
        --libraries=/usr/lib/x86_64-linux-gnu/hdf5/mpich && \
    python3 setup.py install && \
    rm -rf /tmp/pyCGNS

# Install MOAB and pymoab
RUN cd /tmp && \
    git clone --depth=1 https://bitbucket.org/fathomteam/moab.git && \
    cd moab && \
    autoreconf -fi && \
    ./configure \
        --prefix=/usr/local \
        --with-mpi=/usr/lib/mpich \
        CC=mpicc.mpich \
        CXX=mpicxx.mpich \
        FC=mpif90.mpich \
        F77=mpif77.mpich \
        --enable-optimize \
        --enable-shared=yes \
        --with-blas=-lopenblas \
        --with-lapack=-lopenblas \
        --with-scotch=$PETSC_DIR \
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
    
# Install gmsh from source
ARG GMSH_VERSION=3.0.5

RUN cd /tmp && \
    curl -L http://gmsh.info/src/gmsh-$GMSH_VERSION-source.tgz | bsdtar xf - && \
    cd gmsh-$GMSH_VERSION-source && \
    mkdir build && \
    cd build && \
    cmake \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DENABLE_BUILD_LIB=ON \
        -DENABLE_BUILD_SHARED=ON \
        -DENABLE_MPI=ON \
        -DENABLE_OPENMP=ON \
        -DENABLE_WRAP_PYTHON=ON \
        -DPYTHON_EXECUTABLE=/usr/bin/python3.5 \
        -DPYTHON_INCLUDE_DIR=/usr/include/python3.5 \
        -DPYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.5m.so \
        -DENABLE_NUMPY=ON \
        -DBLAS_LAPACK_LIBRARIES=/usr/lib/libopenblas.a \
        -DCMAKE_BUILD_TYPE=Release \
        .. && \
    make -j2 && \
    make install && \
    rm -rf /tmp/*

ADD image/home $DOCKER_HOME

########################################################
# Customization for user
########################################################

USER $DOCKER_USER
WORKDIR $DOCKER_HOME
USER root
