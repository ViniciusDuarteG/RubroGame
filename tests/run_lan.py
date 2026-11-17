#!/usr/bin/env python3
"""Launch host plus two independent Godot clients on loopback. No third-party modules."""
import os, pathlib, subprocess, sys, time
root=pathlib.Path(__file__).resolve().parents[1]
engine=sys.argv[1] if len(sys.argv)>1 else 'godot'
team2=sys.argv[2] if len(sys.argv)>2 else '0'
env=os.environ.copy()
env.update(XDG_DATA_HOME='/tmp/rubro-data',XDG_CONFIG_HOME='/tmp/rubro-config')
processes=[]
try:
    for label,args in [('host',['--test-host']),('clientA',['--test-client','--team=1']),('clientB',['--test-client','--team='+team2])]:
        args+=['--tag='+label,'--scenario='+('opposed' if team2=='0' else 'coop')]
        log=open('/tmp/rubro-lan-'+label+'.log','w')
        process=subprocess.Popen([engine,'--headless','--path',str(root),'--']+args,cwd=root,stdout=log,stderr=subprocess.STDOUT,env=env)
        processes.append((label,process,log))
        if label=='host': time.sleep(1)
    codes=[]
    for label,p,log in processes:
        try: code=p.wait(timeout=105)
        except subprocess.TimeoutExpired: p.kill(); code=124
        log.close(); codes.append(code)
        print(label,code)
        print(pathlib.Path('/tmp/rubro-lan-'+label+'.log').read_text()[-6000:])
    sys.exit(0 if all(c==0 for c in codes) else 1)
finally:
    for _,p,_ in processes:
        if p.poll() is None: p.kill()
