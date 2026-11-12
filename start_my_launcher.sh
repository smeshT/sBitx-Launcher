### this is to restore the file ~/sbitx/web/scripts/start_mylauncher.sh after an update


#1. create file ~/sbitx/web/my_launcher.html
#2. copy content below into it

<!DOCTYPE html>
<html>
<head>
<meta http-equiv="refresh" content="0;url=http://sbitx.local:8090">
</head>
<body>
Redirecting...
</body>
</html>

#3. add this section to ~/sbitx/web/index.html

    <button class="sbitxv3-btn"
            type="button"
            onclick="window.open('/my_launcher.html','_blank');">
        My Apps
    </button>

# at this point in the file (bottom bar)

<div class="bottom-bar">
    <button class="sbitxv3-btn" id="xpra_launch_digi" type="button">Apps</button>
#added here
    <button class="sbitxv3-btn"
            type="button"
            onclick="window.open('/my_launcher.html','_blank');">
        My Apps
    </button>

    <button class="sbitxv3-btn" id="menu-open4">Menu</button>
</div>

# Done
