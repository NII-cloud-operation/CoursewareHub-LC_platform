FROM jupyter/systemuser

### START Stuff from jupyter/systemuser ###

RUN apt-get update
RUN apt-get -y install libpq-dev python-dev
RUN pip install psycopg2
RUN /opt/conda/envs/python2/bin/pip install psycopg2

# Install nano
RUN apt-get -y install nano

# Install terminado
RUN /opt/conda/envs/python2/bin/pip install terminado
RUN pip install terminado

# Install scikit-learn
RUN pip install scikit-learn==0.15

# Install widgets
RUN pip install ipywidgets

# Install standard bash_kernel
RUN pip install bash_kernel
RUN python -m bash_kernel.install

# Install custom bash kernel and extensions
RUN mv /opt/conda/lib/python3.5/site-packages/bash_kernel/kernel.py /opt/conda/lib/python3.5/site-packages/bash_kernel/kernel.py.bak
ADD kernel.py /opt/conda/lib/python3.5/site-packages/bash_kernel/kernel.py

### END Stuff from jupyter/systemuser ###

RUN apt-get -y install curl netcat ssh imagemagick graphviz file rsync jq libgts-0.7-5

RUN /opt/conda/envs/python2/bin/pip install https://storage.googleapis.com/tensorflow/linux/cpu/tensorflow-0.10.0-cp27-none-linux_x86_64.whl

RUN /opt/conda/envs/python2/bin/pip install google-api-python-client
