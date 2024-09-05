





const route = (event) => {
    // console.log(event.target)
    
    let href = getTargetA(event).getAttribute('href')
    event = event || window.event;
    event.preventDefault();
    window.history.pushState({}, "", href);
    handleLocation()

};

const base = ""
const handleLocation = async (ev?: PopStateEvent) => {
    const path = window.location.pathname;
    if (path === "/") return await listArticle(false)
    let article_id = (/^\/article\/(\d+)$(\/)?/.exec(path) || [-1,-1])[1] as number
    if (article_id > 0) {return loadArticle(article_id)}
}

window.onpopstate = handleLocation;
window.onload = (ev) => {
    handleLocation(null)
};


