

function WorkshopFiles()
{
	
}

//
// Initialize
//
WorkshopFiles.prototype.Init = function( namespace, scope, RootScope ) 
{
	var self = this;

	this.NameSpace	= namespace;
	this.Scope		= scope;
	this.RootScope	= RootScope;

	this.Scope.Offset			= 0;
	this.Scope.TotalResults		= 0;
	this.Scope.Category			= "";
	this.Scope.Loading			= true;
	this.Scope.PerPage			= 5;

	this.Scope.Go = function( delta )
	{
		if ( scope.Offset + delta >= scope.TotalResults ) return;
		if ( scope.Offset + delta < 0 ) return;

		scope.SwitchWithTag( scope.Category, scope.Offset + delta, scope.Tagged )
	}

	this.Scope.GoToPage = function( page )
	{
		var Offset = (page-1) * scope.PerPage;

		if ( Offset >= scope.TotalResults ) return;
		if ( Offset < 0 ) return;

		scope.SwitchWithTag( scope.Category, Offset, scope.Tagged )
	}

	
	this.Scope.Switch = function( type, offset )
	{
		this.SwitchWithTag(	type, offset, "" );
		scope.Tagged	= type;
	}
		
	this.Scope.SwitchWithTag = function( type, offset, searchtag, mapname )
	{
		// Fills in perpage
		self.RefreshDimensions();

		scope.Category	= type;
		scope.Tagged	= searchtag;
		scope.MapName	= mapname;
		scope.Offset	= offset;
		scope.Loading	= true;

		if ( !scope.Tagged ) scope.Tagged = '';

		if ( IS_SPAWN_MENU )
		{
			RootScope.Category		= type;
			RootScope.CreationType	= namespace;
			RootScope.Tagged		= searchtag;
		}

		self.UpdatePageNav();

		// fumble
		if ( scope.MapName && scope.Tagged ) 
			lua.Run( self.NameSpace + ":Fetch( %s, %i, %i, { %s, %s } );", scope.Category, scope.Offset, scope.PerPage, scope.Tagged, scope.MapName );
		else if ( scope.MapName ) 
			lua.Run( self.NameSpace + ":Fetch( %s, %i, %i, { %s } );", scope.Category, scope.Offset, scope.PerPage, scope.MapName );
		else
			lua.Run( self.NameSpace + ":Fetch( %s, %i, %i, { %s } );", scope.Category, scope.Offset, scope.PerPage, scope.Tagged );

		if ( !IN_ENGINE )
		{
			setTimeout( function() { WorkshopTestData( scope.Category, self ); }, 0 );
		}
	}

	this.Scope.Rate = function( entry, b )
	{
		if ( !entry.id ) return;

		// Hide the rating icons
		entry.rated = true;

		// Cast our vote
		lua.Run( "steamworks.Vote( %s, "+(b?"true":"false")+" );", String( entry.id ) );

		// Update the scores locally (the votes don't update on the server straight away)
		if ( entry.vote )
		{
			if ( b ) entry.vote.up++; else entry.vote.down++;
		}

		// And play a sound
		if ( b )	lua.PlaySound( "npc/roller/mine/rmine_chirp_answer1.wav" );
		else 		lua.PlaySound( "buttons/button10.wav" );
		
	}

	this.Scope.PublishLocal = function( entry )
	{
		lua.Run( self.NameSpace + ":Publish( %s, %s );", entry.info.file, entry.background );
	}
}

//
// Received a local list of files (think saves on disk)
//
WorkshopFiles.prototype.ReceiveLocal = function( data ) 
{
	this.Scope.Loading			= false;
	this.Scope.TotalResults		= data.totalresults;
	this.Scope.NumResults		= data.results.length;

	this.Scope.Files = []

	for ( k in data.results )
	{
		var entry = 
		{
			order			: k,
			local			: true,
			background		: data.results[k].preview,
			filled			: true,
			info			: 
			{
				title	:	data.results[k].name,
				file	:	data.results[k].file,
			}
		};

		this.Scope.Files.push( entry );
	}

	this.UpdatePageNav();
	this.Changed();
};

//
// The index contains the number of saves, 
// and the save id's - but no details.
// (they come later)
//
WorkshopFiles.prototype.ReceiveIndex = function( data )
{
	this.Scope.Loading			= false;
	this.Scope.TotalResults		= data.totalresults;
	this.Scope.NumResults		= data.numresults;

	this.Scope.Files = []

	for ( k in data.results )
	{
		var entry = 
		{
			order	: k,
			id		: data.results[k],
			filled	: false,
		};

		this.Scope.Files.push( entry );
	}

	this.UpdatePageNav();
	this.Changed();
};

//
// ReceiveFileInfo
//
WorkshopFiles.prototype.ReceiveFileInfo = function( id, data )
{
	for ( k in this.Scope.Files )
	{
		if ( this.Scope.Files[k].id != id ) continue;

		this.Scope.Files[k].filled	= true;
		this.Scope.Files[k].info		= data;

		this.Changed();
	}
},

//
// ReceiveImage
//
WorkshopFiles.prototype.ReceiveImage = function( id, url )
{
	for ( k in this.Scope.Files )
	{
		if ( this.Scope.Files[k].id != id ) continue;

		this.Scope.Files[k].background = url;
		this.Changed();
	}
},

//
// Receive Vote Info
//
WorkshopFiles.prototype.ReceiveVoteInfo = function( id, data )
{
	for ( k in this.Scope.Files )
	{
		if ( this.Scope.Files[k].id != id ) continue;

		this.Scope.Files[k].vote	= data;

		this.Changed();
	}
}

WorkshopFiles.prototype.Changed = function()
{
	this.Scope.$digest();
	
	// An update is queued - so chill
	if ( this.DigestUpdate ) return;

	var self = this;

	// Update the digest in 10ms
	this.DigestUpdate = setTimeout( function ()
	{
		self.DigestUpdate = 0;
		self.Scope.$digest();

	}, 10 )
	
}


WorkshopFiles.prototype.RefreshDimensions = function()
{
	var w = $( "workshopcontainer" ).width();
	var h = $( "workshopcontainer" ).height() - 48;

	var iconswide = Math.floor( w / 180 );
	var iconstall = Math.floor( h / 180 );

	if ( iconswide > 6 ) iconswide = 6;
	if ( iconstall > 4 ) iconstall = 4;

	self.Scope.PerPage = iconswide * iconstall;

	self.Scope.IconWidth		= Math.floor( w / iconswide ) - 26;
	self.Scope.IconHeight		= Math.floor( h / iconstall ) - 26;
	self.Scope.IconMax			= Math.max( self.Scope.IconWidth, self.Scope.IconHeight ) + 1;
}

WorkshopFiles.prototype.UpdatePageNav = function()
{
	self.Scope.Page			= Math.floor(self.Scope.Offset / self.Scope.PerPage) + 1;
	self.Scope.NumPages		= Math.ceil(self.Scope.TotalResults / self.Scope.PerPage);


	if ( self.Scope.NumPages > 32 ) self.Scope.NumPages = 32;

	self.Scope.Pages = [];

	for ( var i=1; i<self.Scope.NumPages+1; i++ )
      self.Scope.Pages.push( i );

}