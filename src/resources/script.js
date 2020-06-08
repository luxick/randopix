function capitalize(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
  }

window.onload = () => {
    const modes = getModes();
    const modeselect = document.getElementById("modeselect");
    modes.forEach(mode => {
        let opt = document.createElement('option');
        opt.value = mode;
        opt.innerHTML = capitalize(mode)
        modeselect.appendChild(opt);
    });
}

function js_setTimeout() {
    const elem = document.getElementById("timeout");
    const timeout = parseInt(elem.value);
    if (timeout < 1) {
        console.error("timeout must be positive");
        return;
    }
    setTimeout(timeout.toString());
    elem.value = null;
}

function js_setMode() {
    const modeselect = document.getElementById("modeselect");
    switchMode(modeselect.value)
}