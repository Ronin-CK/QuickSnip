import QtQuick

QtObject {
    id: root

    property string fullScreenshot
    property string cropJpg
    property string lensHtml
    property string browserClass: "zen"

    function getCommand(x, y, w, h, openIn) {
        const buildHtml = [`echo '<html><body style="margin:0;display:flex;justify-content:center;align-items:center;height:100vh;background:#111;color:#fff;font-family:system-ui"><p>Searching with Google Lens…</p><form id="f" method="POST" enctype="multipart/form-data" action="https://lens.google.com/v3/upload"></form><script>'`, `echo "var b=atob('$B64');"`, `echo 'var a=new Uint8Array(b.length);for(var i=0;i<b.length;i++)a[i]=b.charCodeAt(i);var d=new DataTransfer();d.items.add(new File([a],"i.jpg",{type:"image/jpeg"}));var inp=document.createElement("input");inp.type="file";inp.name="encoded_image";inp.files=d.files;document.getElementById("f").appendChild(inp);document.getElementById("f").submit();'`, `echo '</script></body></html>'`].join(" ; ");
        let openCmd = `xdg-open "${lensHtml}"`;
        if (openIn === "sidebar") {
            const bc = root.browserClass || "zen";
            openCmd = `OLD_CLIP=$(wl-paste --no-newline --type text/plain 2>/dev/null || true); ` +
                      `IMG_B64=$(base64 -w0 "${cropJpg}" 2>/dev/null || base64 -b0 "${cropJpg}") && ` +
                      `printf '%s' "QUICKSNIP_LENS:$IMG_B64" | wl-copy && ` +
                      `sleep 0.05 && wlrctl window focus ${bc} && ` +
                      `sleep 0.1 && wtype -M alt -k s -m alt && ` +
                      `sleep 0.2 && if [ "$(wl-paste)" = "OPEN_SIDEBAR_PLEASE" ]; then ` +
                      `wtype -M alt -k g -m alt && ` +
                      `sleep 0.05 && printf '%s' "QUICKSNIP_LENS:$IMG_B64" | wl-copy ; fi; ` +
                      `sleep 2; printf '%s' "$OLD_CLIP" | wl-copy`;
        } else {
            // Newtab mode: build HTML and open
            let cmd = [`magick "${fullScreenshot}" -crop ${w}x${h}+${x}+${y} -resize '1000x1000>' -strip -quality 85 "${cropJpg}"`, `B64=$(base64 -w0 "${cropJpg}" 2>/dev/null || base64 -b0 "${cropJpg}")`, `{ ${buildHtml} ; } > "${lensHtml}"`, openCmd].join(" && ");
            cmd += ` ; (sleep 15 && rm -f "${fullScreenshot}" "${cropJpg}" "${lensHtml}") &`;
            return cmd;
        }
        let cmd = [`magick "${fullScreenshot}" -crop ${w}x${h}+${x}+${y} -resize '1000x1000>' -strip -quality 85 "${cropJpg}"`, openCmd].join(" && ");
        cmd += ` ; (sleep 15 && rm -f "${fullScreenshot}" "${cropJpg}" "${lensHtml}") &`;
        return cmd;
    }

}
