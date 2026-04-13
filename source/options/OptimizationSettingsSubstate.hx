package options;

class OptimizationSettingsSubstate extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Optimization';
		rpcTitle = 'Optimization Menu';

		var option:Option = new Option('Hide Combo Popup',
			'If checked, the "Combo" text won\'t pop up.',
			'disableComboPopup', 
			BOOL);
		addOption(option);

		var option:Option = new Option('Hide Combo Numbers',
			'If checked, the combo number counter won\'t pop up.',
			'disableComboNumberPopup', 
			BOOL);
		addOption(option);

		var option:Option = new Option('Hide Rating Popup',
			'If checked, ratings like "Sick!" won\'t pop up.',
			'disableComboRatingPopup', 
			BOOL);
		addOption(option);

		super();
	}
}
