package options;

class OptimizationSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Optimization Settings';
		rpcTitle = 'Optimization Settings Menu';

		// Disable Combo Popup
		var option:Option = new Option(
			'Disable Combo Popup',
			'If checked, completely disables combo popups.',
			'disableComboPopup',
			BOOL
		);
		addOption(option);

		// Disable Combo Number Popup
		var option:Option = new Option(
			'Disable Combo Number Popup',
			'If checked, hides combo numbers (e.g. 123, 456).',
			'disableComboNumberPopup',
			BOOL
		);
		addOption(option);

		// Disable Combo Rating Popup
		var option:Option = new Option(
			'Disable Combo Rating Popup',
			'If checked, hides rating text (Sick!, Good!, etc).',
			'disableComboRatingPopup',
			BOOL
		);
		addOption(option);

		super();
	}
}
