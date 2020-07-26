### 项目结构

```
tree 
├── README.md
├── alicdn.ps1                      # 最好与mp4同一目录下
├── h.html        # [hls,js官网例子](https://github.com/video-dev/hls.js#getting-started)
├── movie                           # 分类
│   └── xx                          # alicdn.ps1生成的随机目录
│       ├── 15.ts
│       ├── 17.ts
│       ├── 6.ts
│       ├── video.m3u8
│       └── video_online.m3u8.gif
├── life                           # 分类2
└── pyalicdn.py                    # 尝试上传到公网,已经失效,所以才上传到github

```

### 说明

```bash
# google: ffmpeg n3u8 视频图床
# 下载依赖包
brew cask install powershell ffmpeg

# 把mp4转换成ts格式
ffmpeg -i video1.mp4 -c copy -vbsf h264_mp4toannexb -absf aac_adtstoasc video.ts

# 把ts切片并生成m3us文件(播放列表)
ffmpeg -i video.ts -c copy -f segment -segment_list video.m3u8 %d.ts

# 上传到公网,已经失效
curl https://kfupload.alibaba.com/mupload -X POST -F scene=aeMessageCenterV2ImageRule -F name=image.jpg -F file=@video.ts

# 同video.mp4目录
alicdn.ps1的脚本,就是上面的三条命令

# 同m3u8目录,用python还是上传不了,https://kfupload.alibaba.com
pyalicdn.py:仅仅是上传到公网的作用

```

### 使用

```
./alicdn.ps1

# 然后上传到github上

# md中的引用,如:
<video  controls class="video-content" src='https://cdn.jsdelivr.net/gh/leipengkai/video/1/video.m3u8'></video>

```

#### md其它引用

```
# 不行,还是看不了
<div align="center" class="embed-responsive embed-responsive-16by9">
    <video autoplay loop class="embed-responsive-item">
        <source src="https://cdn.jsdelivr.net/gh/leipengkai/video/1/video.m3u8" type="video/mp4">
    </video>
</div>

<div align="center" class="embed-responsive embed-responsive-16by9">
    <video autoplay loop class="embed-responsive-item" src="https://cdn.jsdelivr.net/gh/leipengkai/video/1/video.m3u8"></video>
</div>

# 直接下载了 不行
<div class="embed-responsive embed-responsive-21by9">
  <iframe class="embed-responsive-item" src="https://cdn.jsdelivr.net/gh/leipengkai/video/1/video.m3u8"></iframe>
</div>

# 不行
<video class="img-responsive" src="https://cdn.jsdelivr.net/gh/leipengkai/video/1/video.m3u8" autoplay loop/>


# 直接跳转到其它页面看了
[![IMAGE ALT TEXT HERE](https://img.youtube.com/vi/YOUTUBE_VIDEO_ID_HERE/0.jpg)](https://www.youtube.com/watch?v=UCJlF5rfc7o)

```


参考:

[小白也能白嫖:jsDelivr+FFmpeg打造切片视频床](https://www.bilibili.com/read/cv6103017/)
[搞事情:用“图床”传视频,自带免费CDN加速(已复活!)](https://akarin.dev/2020/02/07/alicdn-video-hosting/)
