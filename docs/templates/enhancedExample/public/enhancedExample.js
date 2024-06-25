class TabGroup {
    constructor(groupNode) {
        this.tablistNode = groupNode;

        this.tabs = [];

        this.firstTab = null;
        this.lastTab = null;

        this.tabs = Array.from(this.tablistNode.querySelectorAll('[role=tab]'));
        this.tabpanels = [];

        for (var i = 0; i < this.tabs.length; i += 1) {
            var tab = this.tabs[i];

            var tabpanel = document.getElementById(tab.getAttribute('aria-controls'));

            tab.setAttribute('tabIndex', '-1');
            tab.setAttribute('aria-selected', 'false');
            this.tabpanels.push(tabpanel);

            tab.addEventListener('keydown', this.onKeydown.bind(this));
            tab.addEventListener('click', this.onClick.bind(this));

            if (!this.firstTab) {
                this.firstTab = tab;
            }

            this.lastTab = tab;
        }

        this.setSelectedTab(this.firstTab, false);
    }

    setSelectedTab(currentTab, setFocus) {
        if (typeof setFocus !== 'boolean') {
            setFocus = true;
        }

        for (var i = 0; i < this.tabs.length; i += 1) {
            var tab = this.tabs[i];
            if (currentTab === tab) {
                tab.setAttribute('aria-selected', 'true');
                tab.setAttribute('tabindex', 0);
                tab.classList.add('active')
                this.tabpanels[i].removeAttribute('hidden');
                this.tabpanels[i].removeAttribute('aria-hidden');
                if (setFocus) {
                    tab.focus();
                }
            } else {
                tab.setAttribute('aria-selected', 'false');
                tab.setAttribute('tabIndex', '-1');
                tab.classList.remove('active')
                this.tabpanels[i].setAttribute('hidden', 'hidden');
                this.tabpanels[i].setAttribute('aria-hidden', 'true');
            }
        }

        if (setFocus) {
            this.tablistNode.dispatchEvent(new CustomEvent('tabChanged', { detail: currentTab.getAttribute('data-link') }));
        }
    }

    setSelectedTabByData(data) {
        var tab = this.tabs.find(tab => tab.getAttribute('data-link') === data);
        if (tab && tab.classList.contains('active') === false) {
            this.setSelectedTab(tab, false);
        }
    }

    setSelectedToPreviousTab(currentTab) {
        var index;

        if (currentTab === this.firstTab) {
            this.setSelectedTab(this.lastTab);
        } else {
            index = this.tabs.indexOf(currentTab);
            this.setSelectedTab(this.tabs[index - 1]);
        }
    }

    setSelectedToNextTab(currentTab) {
        var index;

        if (currentTab === this.lastTab) {
            this.setSelectedTab(this.firstTab);
        } else {
            index = this.tabs.indexOf(currentTab);
            this.setSelectedTab(this.tabs[index + 1]);
        }
    }

    /* EVENT HANDLERS */

    onKeydown(event) {
        var tgt = event.currentTarget,
            flag = false;

        switch (event.key) {
            case 'ArrowLeft':
                this.setSelectedToPreviousTab(tgt);
                flag = true;
                break;

            case 'ArrowRight':
                this.setSelectedToNextTab(tgt);
                flag = true;
                break;

            case 'Home':
                this.setSelectedTab(this.firstTab);
                flag = true;
                break;

            case 'End':
                this.setSelectedTab(this.lastTab);
                flag = true;
                break;

            default:
                break;
        }

        if (flag) {
            event.stopPropagation();
            event.preventDefault();
        }
    }

    onClick(event) {
        this.setSelectedTab(event.currentTarget);
    }
}

let tabGroups = [];

function alertTabChange(event) {
    for(var i = 0; i < tabGroups.length; i++) {
        tabGroups[i].setSelectedTabByData(event.detail);
    }
}

function register() {
    console.log('Enhanced example plugin started');
    var tablists = document.querySelectorAll('[role=tablist].automatic');
    for (var i = 0; i < tablists.length; i++) {
        var group = new TabGroup(tablists[i]);
        group.tablistNode.addEventListener('tabChanged', alertTabChange);
        tabGroups.push(group);
    }
}

export default {
    start: register
}
