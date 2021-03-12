from setuptools import setup
from Cython.Build import cythonize

setup(
    name='RFXPy',
    ext_modules=cythonize("RFX.pyx"),
    zip_safe=False,
)