from distutils.core import setup
import os, sys, glob

sys.prefix = sys.exec_prefix = '/opt/pygeta'

def read(fname):
    return open(os.path.join(os.path.dirname(__file__), fname)).read()

setup(name="pygeta",
      scripts=['pygeta'],
      version='1.0',
      maintainer="Joshua King",
      maintainer_email="jking_ok@yahoo.com.au",
      description="Monitor and share your progress to arrive at a destination.",
      long_description=read('pygeta.longdesc'),
      data_files=[('/usr/share/applications',['pygeta_harmattan.desktop']),
                  ('/usr/share/icons/hicolor/64x64/apps', ['pygeta.png']),
                  ('/usr/share/icons/hicolor/80x80/apps', ['pygeta80.png']),
                  ('/opt/pygeta/qml', glob.glob('qml/*.qml')),
                  ('/opt/pygeta/qml', glob.glob('qml/*.js')),
                  ('/usr/share/duicontrolpanel/desktops',['pygeta_settings.desktop']),
                  ('/usr/share/duicontrolpanel/uidescriptions',['pygeta_settings.xml']) ],)
