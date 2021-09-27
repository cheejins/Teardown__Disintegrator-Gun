<h1 align="center"> Desintigrator Gun (Teardown Mod) </h1>
<p align="center">A weapon that disintigrates shapes (objects) bit by bit.</p>
<br>
<p align="center">A desintegration step is called each frame only when the desintegration mode is toggled on. Each object has its own list of desintegration positions that spread once those positions (querying the closest point to the desintegrated position) have been desintegrated. This makes for a satisfying, termite like tunneling destruction.</p>
<br>

## Media
* [Demonstration Video](https://www.youtube.com/watch?v=_lC_RJ8JVnw)
* [Youtuber Fynnpire playing the mod](https://youtu.be/ICyXc5I8yxw?t=148)




<br>
  
## Code Overview
Main script files:
* [main.lua](https://github.com/cheejins/Teardown-Mod---Desintigrator-Gun/blob/main/main.lua)
  * Main functionality control center for the mod
  * Contains tool logic and sound functions.
  
* [scripts/desintegrator.lua](https://github.com/cheejins/Teardown-Mod---Disintigrator-Gun/blob/aade129531bb59f444d6263a5339e38875c7ed16/scripts/disintegrator.lua)
  * Contains the main desintegration logic and desintegration object constructor.
  
* [scripts/info.lua](https://github.com/cheejins/Teardown-Mod---Desintigrator-Gun/blob/main/scripts/info.lua)
  * Manages the displaying of the info window.

<br>

## Links
* [Download: Steam Workshop Page](https://steamcommunity.com/sharedfiles/filedetails/?id=2526115498) 
