from setuptools import setup

setup(
    name='sdf',
    version='0.1',
    description='Generate 3D meshes from signed distance functions.',
    author='Michael Fogleman',
    author_email='michael.fogleman@gmail.com',
    packages=['sdf'],
    install_requires=[
        'meshio',
        'numpy',
        'scikit-image',
        'scipy',
        'Pillow',
    ],
    license='MIT',
    classifiers=(
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'Natural Language :: English',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python',
        'Programming Language :: Python :: 3',
    ),
)
