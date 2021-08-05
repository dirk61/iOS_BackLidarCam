# iOS_BackLidarCam

An example using ARVideoKit for simultaneous Lidar Depth Map Capture & Video Recording.



##### Files will be saved at the local directory, including:

* a **MP4** format back camera video (30fps, 1940 * 1440)
* A **zip** file containing the stored depth maps (30fps 256 * 192). Use *ReadDepth.ipynb* in the notebook
* a **txt** file recording the timestamp of each depth frame for future synchronization



![image](https://github.com/dirk61/iOS_BackLidarCam/blob/master/images/1555b7ed-b9fe-4ab8-b6c9-29f40c35d2b0.png)



##### Process the zip file of Depth maps

Follow the instructions in the Jupiter notebook. You can retrieve all the frames in arrays and do whatever you want, e.g. generate a depth video.

![image](https://github.com/dirk61/iOS_BackLidarCam/blob/master/images/IMG_3964.PNG)
