{% if page.comments && theme.gitalk.enable %}    
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/gitalk@1/dist/gitalk.css">
  <script src="https://cdn.jsdelivr.net/npm/gitalk@1/dist/gitalk.min.js"></script>
  <script type="text/javascript">
	  var gitalk = new Gitalk({
		clientID:  '{{theme.gitalk.clientID}}', 
		clientSecret: '{{theme.gitalk.clientSecret}}',
		id: '{{ page.date }}',
		repo: '{{theme.gitalk.repo}}', 
		owner: '{{theme.gitalk.owner}}', 
		admin: '{{theme.gitalk.admin}}', 
		distractionFreeMode: '{{theme.gitalk.distractionFreeMode}}',
	  })
	  gitalk.render('gitalk-container')
  </script>
{% endif %}

