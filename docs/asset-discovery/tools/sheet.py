import sys,os
from PIL import Image,ImageDraw,ImageFont
src,out,cols,cell=sys.argv[1],sys.argv[2],int(sys.argv[3]),int(sys.argv[4])
files=sorted(f for f in os.listdir(src) if f.endswith(".png"))
per=cols*int(sys.argv[5])
os.makedirs(out,exist_ok=True)
for k in range(0,len(files),per):
    chunk=files[k:k+per]; rows=(len(chunk)+cols-1)//cols
    im=Image.new("RGB",(cols*cell,rows*(cell+14)),"white"); d=ImageDraw.Draw(im)
    for i,f in enumerate(chunk):
        t=Image.open(os.path.join(src,f)).convert("RGB").resize((cell,cell))
        x=(i%cols)*cell;y=(i//cols)*(cell+14)
        im.paste(t,(x,y)); d.text((x+2,y+cell),f[:-4].replace("SM_","")[:30],fill="black")
    im.save(os.path.join(out,"sheet_%02d.png"%(k//per)))
print(len(files))
