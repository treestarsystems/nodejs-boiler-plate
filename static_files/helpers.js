function registerHelpers (hbs) {
 hbs.handlebars.registerHelper('loadCustomJS', function(customJSArray) {
   let html = '';
   for (let i = 0; i < customJSArray.length; i++) {
    html += `<script src="${customJSArray[i]}"></script>\n`;
   }
   return html;
 })
}

module.exports = {
 registerHelpers
}
